import 'package:flutter/material.dart';

import '../dto/bible.dart';
import '../dto/pericope.dart';
import '../utils/bible_style.dart';
import '../utils/reading_style.dart';
import 'pericope_block.dart';

/// Глава в нескольких изданиях — построчным чередованием.
///
/// Колонки на телефоне исключены арифметикой: 360 dp на два столбца дают около
/// двадцати знаков в строке, а церковнославянский с титлами в такой колонке
/// нечитаем вовсе. Сайт рисует таблицу и может себе это позволить; мы нет.
///
/// Поэтому на каждое каноническое место — блок: номер стиха, под ним по строке
/// на издание. Читать так главу подряд нельзя — но в параллельном виде этого и
/// не делают, в нём сличают.
class BibleParallelView extends StatelessWidget {
  const BibleParallelView({
    super.key,
    required this.chapter,
    required this.fontSize,
    this.highlight = const [],
    this.rangesLabel = "",
    this.firstKey,
  });

  final BibleChapter chapter;
  final double fontSize;

  /// Границы зачала, если пришли со страницы дня.
  ///
  /// Подсветка нужна и здесь, а не только в сплошном тексте: сличать зачало по
  /// двум изданиям идут не реже, чем читать его по одному, и без границ читатель
  /// снова оказался бы перед задачей искать начало чтения глазами.
  final List<PericopeRange> highlight;
  final String rangesLabel;
  final GlobalKey? firstKey;

  @override
  Widget build(BuildContext context) {
    final color = readingTextColor(context);
    final muted = color.withValues(alpha: 0.6);

    if (highlight.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: chapter.rows.map((row) => _row(context, row, color, muted)).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _withPericope(context, color, muted),
    );
  }

  /// Строки, сгруппированные в куски внутри и вне зачала.
  ///
  /// Группируем, а не обводим каждую строку по отдельности: подряд идущие стихи
  /// зачала — один отрывок, и десяток рамок подряд читался бы как десяток разных
  /// чтений.
  List<Widget> _withPericope(BuildContext context, Color color, Color muted) {
    bool inside(BibleRow row) =>
        highlight.any((range) => range.contains(chapter.chapter, row.verse));

    final blocks = <Widget>[];
    var run = <BibleRow>[];
    var runInside = false;

    void flush() {
      if (run.isEmpty) return;
      final rows = run.map((row) => _row(context, row, color, muted)).toList();
      final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);

      if (!runInside) {
        blocks.add(body);
      } else {
        final first = startsPericope(highlight, chapter.chapter, run.first.verse);
        final last = endsPericope(highlight, chapter.chapter, run.last.verse);
        blocks.add(pericopeFrame(
          context,
          child: body,
          rangesLabel: rangesLabel,
          fontSize: fontSize,
          isFirst: first,
          isLast: last,
          anchorKey: first ? firstKey : null,
        ));
      }
      run = <BibleRow>[];
    }

    for (final row in chapter.rows) {
      final here = inside(row);
      if (run.isNotEmpty && here != runInside) flush();
      runInside = here;
      run.add(row);
    }
    flush();

    return blocks;
  }

  Widget _row(BuildContext context, BibleRow row, Color color, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${row.verse}",
            style: TextStyle(
              fontFamily: "OldStandard",
              fontSize: fontSize * 0.8,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 2.0),
          ...List.generate(
            chapter.editions.length,
            (index) => _cell(
              context,
              chapter.editions[index],
              index < row.cells.length ? row.cells[index] : null,
              color,
              muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    BibleEdition edition,
    BibleCell? cell,
    Color color,
    Color muted,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  edition.shortTitle,
                  style: TextStyle(fontSize: fontSize * 0.65, color: muted),
                ),
                // Родной номер подписывается только там, где он разошёлся с
                // каноническим. По нему стих ищут в бумажной книге, и подменять
                // один номер другим молча нельзя: в девятом псалме у румынского
                // издания так напечатаны тридцать восемь стихов из тридцати девяти.
                if (cell != null && cell.shifted)
                  Text(
                    "${cell.editionChapter}:${cell.editionVerse}",
                    style: TextStyle(fontSize: fontSize * 0.6, color: muted),
                  ),
              ],
            ),
          ),
          Expanded(
            child: cell == null
                // Пропуск рисуется, а не пропускается: молчаливо пропущенную
                // строку читатель принимает за нашу недоработку, тогда как это
                // свойство издания — оно этого стиха не печатает.
                ? Text(
                    "в этом издании стиха нет",
                    style: TextStyle(
                      fontSize: fontSize * 0.8,
                      color: muted,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Text(
                    cell.content,
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontFamily: bibleFontFamily(edition.language),
                      fontSize: fontSize,
                      color: color,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
