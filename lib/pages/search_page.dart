import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../api/search.dart' show minSearchQueryLength;
import '../apiMapper/search.dart';
import '../apiMapper/singing.dart';
import '../components/paged_list.dart';
import '../components/snippet_text.dart';
import '../dto/chant.dart';
import '../dto/incipit.dart';
import '../dto/search.dart';
import '../store/models/models.dart';
import '../utils/incipit_route.dart';
import '../utils/chant_style.dart';
import '../utils/singing_labels.dart';

/// Поиск: по текстам чтений, по первым словам песнопения и по самим песнопениям.
///
/// **Одна страница, а не три пункта меню.** Вопрос у читателя один — «где это?».
/// Вкладка отвечает не на другой вопрос, а на «где искать». Разведя их по меню,
/// мы заставили бы выбирать раздел прежде, чем сформулирован запрос.
///
/// Строка запроса поэтому одна на все вкладки: набрал раз — можно посмотреть
/// в каждом корпусе, не перенабирая.
///
/// Вкладки в приложении не новость (`main_page`, `saint_page`), но там все три
/// вида делят один запрос и один `Future`. Здесь у каждой вкладки своя выдача,
/// своя постраничность и свои отказы — и это первое такое место, так что образец
/// искать не там.
class SearchPage extends StatefulWidget {
  const SearchPage(context, {super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late final TabController _tabs;

  /// Запрос, по которому уже ищем. Отдельно от текста в поле: поле меняется на
  /// каждой букве, а искать по каждой букве незачем.
  String _query = "";
  String _typed = "";
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _typed = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _runSearch);
  }

  void _runSearch() {
    _debounce?.cancel();
    setState(() => _query = _typed.trim());
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _typed = "";
      _query = "";
    });
  }

  double get _fontSize =>
      StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Поиск", style: TextStyle(fontFamily: "OldStandard")),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: "Чтения"),
            Tab(text: "Зачины"),
            Tab(text: "Песнопения"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: "Слово или строка",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _typed.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), onPressed: _clear),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _texts(),
                _incipits(),
                _chants(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Чтения: прежний поиск по библиотеке, без постраничности и без подсветки.

  Widget _texts() {
    if (_query.isEmpty) {
      return searchHint("Поиск идёт по названиям и по самим текстам — "
          "можно искать слово или строку из чтения.");
    }

    return FutureBuilder<List<SearchBookText>>(
      key: ValueKey("texts:$_query"),
      future: getSearchResult(_query),
      builder: (context, future) {
        if (future.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (future.error is SearchQueryTooShortException) {
          return searchHint("Введите хотя бы $minSearchQueryLength символа.");
        }
        if (future.hasError) {
          // Тем же видом, что и поиск по песнопениям: вторая версия API
          // называет причину сама, и «Повторить» показывается только там, где
          // повтор поможет. Прежде отказ по ключу и превышение частоты
          // выглядели одинаково — «не удалось выполнить поиск» с кнопкой,
          // которая ничего не меняла.
          return searchErrorView(
            context,
            future.error!,
            "Не удалось выполнить поиск.",
            () => setState(() {}),
          );
        }

        final items = future.data ?? const <SearchBookText>[];
        if (items.isEmpty) {
          return searchHint("Ничего не нашлось. Попробуйте другое слово или его часть.");
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) => _textTile(items[index]),
        );
      },
    );
  }

  Widget _textTile(SearchBookText item) {
    final excerpt = item.excerpt;
    return ListTile(
      title: Text(item.name,
          style: const TextStyle(fontFamily: "OldStandard", fontWeight: FontWeight.bold)),
      subtitle: item.author == null && excerpt == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.author != null) Text(item.author!),
                // Совпадение здесь не подсвечено, и это осознанно: фрагмент
                // приходит строкой, а искали по нормализованной форме — подсветка
                // по подстроке промахнулась бы чаще, чем попала.
                if (excerpt != null)
                  Text(excerpt, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
      isThreeLine: excerpt != null,
      onTap: () => Navigator.pushNamed(context, "/reading", arguments: item.id),
    );
  }

  // --- Зачины: указатель по первым словам.

  Widget _incipits() {
    if (_query.isEmpty) {
      return searchHint("Указатель по первым словам песнопения: "
          "наберите начало — «воду прошед», «свете тихий».");
    }

    return PagedList<Incipit>(
      key: const ValueKey("incipits"),
      resetToken: _query,
      load: (offset) => getIncipits(_query, offset: offset),
      emptyMessage: "Такого зачина в указателе нет.",
      errorMessage: "Не удалось найти зачин.",
      itemBuilder: (context, item) => _incipitTile(item),
    );
  }

  Widget _incipitTile(Incipit item) {
    final where = [
      if (item.memory != null) item.memory!,
      if (item.akathist != null) item.akathist!,
      if (item.book != null) bookLabel(item.book),
    ].join(" · ");

    return ListTile(
      title: Text(item.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: "OldStandard", fontSize: _fontSize)),
      subtitle: Text([
        languageLabel(item.language),
        // Число вхождений — главное, что говорит строка указателя: «воду
        // прошед» встречается сто тридцать раз, а не единожды.
        "вхождений: ${item.uses}",
        if (where.isNotEmpty) where,
      ].join(" · ")),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(
        context,
        "/incipit",
        arguments: incipitRouteArgument(item.language, item.incipit),
      ),
    );
  }

  // --- Песнопения: поиск по самим текстам служб.

  Widget _chants() {
    if (_query.isEmpty) {
      return searchHint("Поиск по стихирам, седальнам, тропарям и ирмосам "
          "Октоиха, Миней, Триодей и Ирмология.");
    }

    return PagedList<Chant>(
      key: const ValueKey("chants"),
      resetToken: _query,
      load: (offset) => getChants(_query, offset: offset),
      emptyMessage: "Ничего не нашлось. Попробуйте другое слово или его часть.",
      errorMessage: "Не удалось выполнить поиск по песнопениям.",
      itemBuilder: (context, item) => _chantTile(item),
    );
  }

  Widget _chantTile(Chant item) {
    // Язык приходит не всегда: сервер начал отдавать его недавно, и на не
    // обновлённом сервере поля нет. Пустое значение выкидываем, а не оставляем
    // висеть разделителем.
    final subtitle = [languageLabel(item.language), ...chantAddress(item)]
        .where((part) => part.isNotEmpty)
        .join(" · ");
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SnippetText(
            parts: item.snippet,
            fontSize: _fontSize,
            fontFamily: chantFontFamily(item.language),
          ),
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
