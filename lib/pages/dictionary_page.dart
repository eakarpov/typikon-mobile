
import 'package:flutter/material.dart';

import '../components/faceted_search.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../apiMapper/reference.dart';
import '../components/api_error_view.dart';
import '../components/paged_list.dart';
import '../dto/reference.dart';
import '../store/models/models.dart';
import '../utils/lexeme_labels.dart';

/// Словарь церковнославянского: слово и его склонение.
class DictionaryPage extends StatefulWidget {
  const DictionaryPage(context, {super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Словарь", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: SearchQueryField(
              hintText: "Начало слова",
              autofocus: true,
              delay: const Duration(milliseconds: 500),
              onQuery: (query) => setState(() => _query = query),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? searchHint("Поиск идёт по началу слова. "
                    "Гражданкой тоже находит: «земл» найдёт «земледѣ́ланіе».")
                : PagedList<LexemeSummary>(
                    resetToken: _query,
                    load: (offset) => getLexemes(_query, offset: offset),
                    emptyMessage: "Такого слова в словаре нет.",
                    errorMessage: "Не удалось выполнить поиск по словарю.",
                    itemBuilder: (context, item) => ListTile(
                      title: Text(item.name,
                          style: const TextStyle(fontFamily: "Monomakh", fontSize: 18.0)),
                      subtitle: Text([
                        partOfSpeechLabel(item.pos),
                        // В строке списка помета одна и кодом: место узкое, а
                        // разбор целиком показывается в самой статье.
                        if (item.properties.isNotEmpty) item.properties,
                      ].where((part) => part.isNotEmpty).join(" · ")),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.pushNamed(context, "/dictionary", arguments: item.id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Словарная статья с парадигмой.
class LexemePage extends StatefulWidget {
  const LexemePage(context, {super.key, required this.id});

  final String id;

  @override
  State<LexemePage> createState() => _LexemePageState();
}

class _LexemePageState extends State<LexemePage> {
  late Future<Lexeme> lexeme;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    lexeme = getLexeme(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize =
        StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Lexeme>(
          future: lexeme,
          builder: (context, future) => Text(
            future.hasData ? future.data!.name : "Словарь",
            style: const TextStyle(fontFamily: "Monomakh"),
          ),
        ),
      ),
      body: FutureBuilder<Lexeme>(
        future: lexeme,
        builder: (context, future) {
          if (future.hasError) {
            return errorViewFor(
              context,
              future.error!,
              "Не удалось открыть словарную статью.",
              () => setState(_load),
            );
          }
          if (!future.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _body(context, future.data!, fontSize);
        },
      ),
    );
  }

  Widget _body(BuildContext context, Lexeme data, double fontSize) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
      children: [
        Text(
          [partOfSpeechLabel(data.pos), ...propertyLabels(data.pos, data.properties)]
              .where((part) => part.isNotEmpty)
              .join(" · "),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (!data.known)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              // Пустая таблица иначе читается как «слово не склоняется».
              "Таблицы склонения для этой схемы нет — показаны только формы, "
              "выписанные в самом словаре.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        // Пояснение к точке стоит ПЕРЕД таблицами, а не после них. Стояло после
        // — и на устройстве стало видно, чего не видно в коде: склонение
        // существительного это два десятка строк, и читатель встречал точку
        // задолго до того, как узнавал, что она значит.
        if (data.paradigms.isNotEmpty || data.extra.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              // Разница между фактом и выводом должна быть видна, а не подразумеваться.
              "Точкой отмечено выписанное в самом словаре; прочее порождено по "
              "таблице склонения.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ...data.paradigms.map((paradigm) => _paradigm(context, paradigm, fontSize)),
        if (data.extra.isNotEmpty) ...[
          _heading(context, "Прочие формы"),
          ...data.extra.map((form) => _form(context, form, fontSize)),
        ],
      ],
    );
  }

  Widget _paradigm(BuildContext context, LexemeParadigm paradigm, double fontSize) {
    final rows = paradigm.slots.where((slot) => slot.forms.isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, paradigmTitle(paradigm)),
        ...rows.map((slot) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120.0,
                    child: Text(
                      slotLabel(slot.slot),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 12.0,
                      children: slot.forms
                          .map((form) => _form(context, form, fontSize))
                          .toList(),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _form(BuildContext context, LexemeForm form, double fontSize) => Text(
        // Точка у выписанной формы, а не у порождённой: пометить надо то, что
        // засвидетельствовано, а не то, что выведено.
        form.stored ? "${form.value} ·" : form.value,
        style: TextStyle(fontFamily: "Monomakh", fontSize: fontSize),
      );

  Widget _heading(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: "OldStandard",
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}
