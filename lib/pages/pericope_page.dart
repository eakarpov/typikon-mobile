import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../apiMapper/pericopes.dart';
import '../components/paged_list.dart';
import '../components/verse_list.dart';
import '../dto/pericope.dart';
import '../store/models/models.dart';
import '../utils/bible_route.dart';

/// Зачало целиком: где читается, что читается и где это в книге.
class PericopePage extends StatefulWidget {
  const PericopePage(context, {super.key, required this.id});

  final String id;

  @override
  State<PericopePage> createState() => _PericopePageState();
}

class _PericopePageState extends State<PericopePage> {
  late Future<PericopeReading> reading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    reading = getPericope(widget.id);
  }

  void _openInBible(PericopeEntry entry) {
    Navigator.pushNamed(
      context,
      "/bible",
      arguments: bibleRouteArgument(
        entry.bookSlug!,
        chapter: entry.ranges.first.chapterFrom,
        ranges: entry.ranges,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = StoreProvider.of<AppState>(context).state.settings;

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<PericopeReading>(
          future: reading,
          builder: (context, future) => Text(
            future.hasData ? future.data!.entry.label : "Зачало",
            style: const TextStyle(fontFamily: "OldStandard"),
          ),
        ),
      ),
      body: Container(
        color: settings.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        child: FutureBuilder<PericopeReading>(
          future: reading,
          builder: (context, future) {
            if (future.hasError) {
              return searchErrorView(
                context,
                future.error!,
                "Не удалось загрузить зачало.",
                () => setState(_load),
              );
            }
            if (!future.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _body(context, future.data!, settings.fontSize.toDouble());
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, PericopeReading data, double fontSize) {
    final entry = data.entry;
    final where = entry.occasions.join("; ");

    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
      children: [
        if (data.textName != null || entry.ranges.isNotEmpty)
          Text(
            [if (data.textName != null) data.textName!, entry.rangesLabel]
                .where((part) => part.isNotEmpty)
                .join(", "),
            style: const TextStyle(fontFamily: "OldStandard", fontWeight: FontWeight.bold),
          ),
        if (where.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(where, style: Theme.of(context).textTheme.bodySmall),
          ),
        if (data.fellBack)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              // Откатилось чтение ЦЕЛИКОМ, а не недостающая часть: сшитый из двух
              // изданий отрывок выглядел бы цельным, не будучи им.
              "На запрошенном языке это чтение не собралось — показано "
              "церковнославянское.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const Divider(height: 24.0),
        if (data.verses.isEmpty)
          const Text("Текст этого зачала ещё не размечен.")
        else
          VerseListView(verses: data.verses, fontSize: fontSize, fontFamily: "Monomakh"),
        if (entry.opensInBible)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                // Тот же путь, что со страницы дня: зачало из указателя
                // открывается там же, где зачало из чтений дня.
                onPressed: () => _openInBible(entry),
                child: const Text("Читать целиком →"),
              ),
            ),
          ),
      ],
    );
  }
}
