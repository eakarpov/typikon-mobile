import 'dart:async';

import 'package:flutter/material.dart';

import '../apiMapper/singing.dart';
import '../components/paged_list.dart';
import '../dto/corpus.dart';
import '../dto/paged.dart';
import '../utils/singing_labels.dart';

/// Каноны книг: Октоих, Минеи, Триоди, Минея общая.
///
/// **Пустой запрос — не ошибка, а начало просмотра.** Тем раздел и отличается
/// от поиска по песнопениям: там без слова показывать нечего — корпус в двести
/// тридцать шесть тысяч строк, — а здесь перечень канонов сам по себе и есть
/// содержимое раздела. Поиск его сужает, а не открывает.
///
/// **Отборы приходят с сервера, а не зашиты здесь.** Значения берутся из самого
/// корпуса; зашитый список разошёлся бы с ним молча, как только там заведут
/// новую роль. Ровно поэтому у поиска фильтров нет до сих пор.
class CanonsPage extends StatefulWidget {
  const CanonsPage(context, {super.key});

  @override
  State<CanonsPage> createState() => _CanonsPageState();
}

class _CanonsPageState extends State<CanonsPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String _query = "";
  String _typed = "";

  String? _book;
  int? _tone;
  String? _service;
  String? _role;

  CanonFacets _facets = const CanonFacets();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _typed = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = _typed.trim());
    });
  }

  /// Всё, от чего зависит выдача. Сменилось — список начинается заново.
  String get _token => "$_query|$_book|$_tone|$_service|$_role";

  Future<Paged<Canon>> _load(int offset) async {
    final page = await getCanons(
      query: _query, offset: offset, book: _book, tone: _tone, service: _service, role: _role,
    );

    // Отборы приезжают с каждой страницей, но берём их с первой: на второй они
    // те же, а перерисовывать полосу отборов посреди прокрутки незачем.
    if (mounted && offset == 0) setState(() => _facets = page.facets);

    return Paged<Canon>(
      items: page.items, total: page.total, limit: page.limit, offset: page.offset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Каноны", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
              child: TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  // Имена стоят так, как их пишет книга: в родительном падеже.
                  hintText: "Имя или творец: Николая, Дамаскина",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _typed.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _typed = "";
                              _query = "";
                            });
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            _filters(),
            Expanded(
              child: PagedList<Canon>(
                resetToken: _token,
                load: _load,
                emptyMessage: "Ни одного канона не нашлось.",
                errorMessage: "Не удалось открыть каноны.",
                itemBuilder: (context, canon) => _CanonTile(canon: canon),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    // Показываем только то, чем и вправду можно сузить: отбор с одним значением
    // ничего не отбирает, а место занимает.
    final chips = <Widget>[
      if (_facets.books.length > 1)
        _choice<String>(
          label: "книга",
          value: _book,
          values: _facets.books,
          nameOf: bookLabel,
          onPicked: (value) => setState(() => _book = value),
        ),
      if (_facets.tones.length > 1)
        _choice<int>(
          label: "глас",
          value: _tone,
          values: _facets.tones,
          nameOf: (tone) => "глас $tone",
          onPicked: (value) => setState(() => _tone = value),
        ),
      if (_facets.services.length > 1)
        _choice<String>(
          label: "служба",
          value: _service,
          values: _facets.services,
          nameOf: serviceLabel,
          onPicked: (value) => setState(() => _service = value),
        ),
      if (_facets.roles.length > 1)
        _choice<String>(
          label: "роль",
          value: _role,
          values: _facets.roles,
          nameOf: canonRoleLabel,
          onPicked: (value) => setState(() => _role = value),
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 52.0,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        children: chips,
      ),
    );
  }

  Widget _choice<T>({
    required String label,
    required T? value,
    required List<T> values,
    required String Function(T) nameOf,
    required void Function(T?) onPicked,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child: PopupMenuButton<T?>(
        onSelected: onPicked,
        itemBuilder: (context) => [
          PopupMenuItem<T?>(value: null, child: Text("любая $label")),
          ...values.map((item) => PopupMenuItem<T?>(value: item, child: Text(nameOf(item)))),
        ],
        child: Chip(
          label: Text(value == null ? label : nameOf(value)),
          avatar: Icon(
            value == null ? Icons.filter_list : Icons.check,
            size: 16.0,
          ),
        ),
      ),
    );
  }
}

class _CanonTile extends StatelessWidget {
  const _CanonTile({required this.canon});

  final Canon canon;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;

    final address = <String>[
      bookLabel(canon.book),
      memoryAddress(
        book: canon.book,
        month: canon.month,
        day: canon.day,
        paschaOffset: canon.paschaOffset,
        weekday: canon.weekday,
        memoryTone: canon.memoryTone,
      ),
      serviceLabel(canon.service),
      if (canon.tone != null) "глас ${canon.tone}",
      canonRoleLabel(canon.role),
      // Язык издания: английский канон иначе неотличим от славянского — подписи
      // у них одни и те же.
      languageLabel(canon.language),
    ].where((part) => part.isNotEmpty).join(" · ");

    // Надписание книги, а не отождествлённое лицо: в перечне довольно того, что
    // напечатано, — отождествление показывается в самой карточке.
    final about = <String>[
      canon.odes > 0 ? "песней ${canon.odes}" : "песней нет",
      if ((canon.creator ?? "").isNotEmpty) canon.creator!,
    ].join(" · ");

    return ListTile(
      title: Text(
        canon.memory.isEmpty ? "Без метки памяти" : canon.memory,
        style: const TextStyle(fontFamily: "OldStandard"),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address.isNotEmpty) Text(address, style: small),
          Text(about, style: small),
        ],
      ),
      onTap: () => Navigator.pushNamed(context, "/canons", arguments: canon.id),
    );
  }
}
