import 'package:flutter/material.dart';

import '../apiMapper/bible.dart';
import '../components/async_view.dart';
import '../dto/bible.dart';
import '../dto/concordance.dart';
import '../dto/pericope.dart';
import '../utils/bible_route.dart';

/// Где канонический стих стоит в каждом издании собрания.
///
/// Пара «глава:стих» ничего не значит, пока не сказано, чьим счётом она
/// названа: у румынской Псалтири в девятом псалме стихов на один меньше, и
/// каноническому «9:13» там отвечает «9:12». Этот экран по одному
/// каноническому адресу показывает место стиха в каждом издании.
class ConcordancePage extends StatefulWidget {
  const ConcordancePage(
    context, {
    super.key,
    required this.ref,
    this.concordance = getConcordance,
    this.editions = getBibleEditions,
    this.books = getBibleBooks,
  });

  /// Канонический адрес стиха: «книга.глава.стих», напр. `psaltir.9.13`.
  final String ref;

  /// Согласование нумераций. Подменяется тестом.
  final Future<Concordance> Function(String ref) concordance;

  /// Список изданий — для человеческих имён; незнакомый код показывается как есть.
  final Future<BibleEditionList> Function() editions;

  /// Оглавление Библии — для имён книг в местах; незнакомый slug — как есть.
  final Future<BibleBookList> Function() books;

  @override
  State<ConcordancePage> createState() => _ConcordancePageState();
}

class _ConcordancePageState extends State<ConcordancePage> {
  late Future<Concordance> _concordance;

  BibleEditionList _editions = const BibleEditionList([]);
  BibleBookList _books = const BibleBookList([]);

  @override
  void initState() {
    super.initState();
    _load();
    _loadLookups();
  }

  void _load() {
    _concordance = widget.concordance(widget.ref);
  }

  /// То же обновление, но жестом. Ждём ответа: иначе кольцо пропадёт раньше.
  Future<void> _refresh() {
    setState(_load);
    return settle(_concordance);
  }

  /// Имена изданий и книг — прибавка к ответу: не пришли — покажем коды и
  /// slug'и как есть, отказ основного запроса они не роняют.
  Future<void> _loadLookups() async {
    try {
      final editions = await widget.editions();
      if (mounted) setState(() => _editions = editions);
    } catch (_) {}
    try {
      final books = await widget.books();
      if (mounted) setState(() => _books = books);
    } catch (_) {}
  }

  String _editionName(String code) {
    for (final edition in _editions.list) {
      if (edition.code == code) return edition.title;
    }
    return code;
  }

  String _bookName(String id) => _books.byId(id)?.name ?? id;

  /// Канонический адрес из ответа: «книга.глава.стих».
  ///
  /// Места в изданиях напечатаны в собственном счёте каждого издания, а
  /// маршрут `/bible` и его подсветка ждут канонический счёт: выделить надо
  /// каноническое место, а не напечатанное в издании.
  ({String book, int chapter, int verse})? _canonTarget(String canonRef) {
    final parts = canonRef.split(".");
    if (parts.length != 3) return null;
    final chapter = int.tryParse(parts[1]);
    final verse = int.tryParse(parts[2]);
    if (chapter == null || verse == null) return null;
    return (book: parts[0], chapter: chapter, verse: verse);
  }

  void _openPlace(BuildContext context, Concordance data, ConcordancePlace place) {
    final target = _canonTarget(data.canonRef);
    Navigator.pushNamed(
      context,
      "/bible",
      arguments: bibleRouteArgument(
        target?.book ?? place.book,
        chapter: target?.chapter ?? place.chapter,
        ranges: [
          if (target != null)
            PericopeRange(
              chapterFrom: target.chapter,
              verseFrom: target.verse,
              chapterTo: target.chapter,
              verseTo: target.verse,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Concordance>(
          future: _concordance,
          builder: (context, future) => Text(
            future.hasData ? "Стих в изданиях: ${future.data!.canonRef}" : "Стих в изданиях",
            style: const TextStyle(fontFamily: "OldStandard", fontSize: 18.0),
          ),
        ),
      ),
      body: AsyncView<Concordance>(
        future: _concordance,
        message: "Не удалось узнать, в каких изданиях печатается стих.",
        onRetry: () => setState(_load),
        onRefresh: _refresh,
        isEmpty: (data) => data.editions.isEmpty,
        emptyMessage: "Этот стих не печатает ни одно издание собрания.",
        builder: (context, data) => _body(context, data),
      ),
    );
  }

  Widget _body(BuildContext context, Concordance data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 32.0),
      children: [
        for (final edition in data.editions) ..._editionSection(context, data, edition),
      ],
    );
  }

  List<Widget> _editionSection(
      BuildContext context, Concordance data, ConcordanceEdition edition) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Text(
          _editionName(edition.edition),
          style: const TextStyle(fontFamily: "OldStandard", fontWeight: FontWeight.bold),
        ),
      ),
      for (final place in edition.places)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            "${_bookName(place.book)} ${place.chapter}:${place.verse}",
            style: const TextStyle(fontFamily: "OldStandard"),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPlace(context, data, place),
        ),
    ];
  }
}
