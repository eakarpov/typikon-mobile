import 'package:flutter/material.dart';

import '../dto/bible.dart';
import '../utils/bible_style.dart';
import '../utils/reading_style.dart';

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
  });

  final BibleChapter chapter;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = readingTextColor(context);
    final muted = color.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: chapter.rows
          .map((row) => _row(context, row, color, muted))
          .toList(),
    );
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
