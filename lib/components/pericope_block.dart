import 'package:flutter/material.dart';

import '../dto/pericope.dart';
import '../utils/pericope_route.dart';
import 'verse_list.dart';

/// Зачало, подсвеченное внутри главы.
///
/// Границы (`ranges`) сервер отдавал всё это время, и по ним видно не только где
/// чтение начинается, но и где кончается — без подсветки первое приходилось
/// искать глазами, а второе не понять вовсе.
///
/// Зачало бывает разорванным и переходящим через границу главы, поэтому «начало»
/// и «конец» определяются не порядком кусков на экране, а сверкой с самими
/// границами: кусок подписан началом, если раньше него в зачале ничего нет, и
/// концом, если после него ничего нет. Сравнение по месту, а не по счёту кусков,
/// потому что глава показывается по одной, а зачало может уходить в следующую.
int _position(int chapter, int verse) => chapter * 1000 + verse;

List<Widget> buildPericopeBlocks(
  BuildContext context, {
  required List<PericopeVerse> verses,
  required List<PericopeRange> ranges,
  required double fontSize,
  required String fontFamily,
  required String rangesLabel,
  GlobalKey? firstKey,
}) {
  if (ranges.isEmpty || verses.isEmpty) {
    return [_plain(verses, fontSize, fontFamily)];
  }

  final start = _position(ranges.first.chapterFrom, ranges.first.verseFrom);
  final end = _position(ranges.last.chapterTo, ranges.last.verseTo);

  final blocks = <Widget>[];
  for (final run in splitVerseRuns(verses, ranges)) {
    if (!run.inPericope) {
      blocks.add(_plain(run.verses, fontSize, fontFamily));
      continue;
    }

    final first = _position(run.verses.first.chapter, run.verses.first.verse) <= start;
    final last = _position(run.verses.last.chapter, run.verses.last.verse) >= end;

    blocks.add(_highlighted(
      context,
      run.verses,
      fontSize,
      fontFamily,
      rangesLabel: rangesLabel,
      isFirst: first,
      isLast: last,
      anchorKey: first ? firstKey : null,
    ));
  }
  return blocks;
}

Widget _plain(List<PericopeVerse> verses, double fontSize, String fontFamily) =>
    VerseListView(verses: verses, fontSize: fontSize, fontFamily: fontFamily);

Widget _highlighted(
  BuildContext context,
  List<PericopeVerse> verses,
  double fontSize,
  String fontFamily, {
  required String rangesLabel,
  required bool isFirst,
  required bool isLast,
  GlobalKey? anchorKey,
}) {
  final scheme = Theme.of(context).colorScheme;
  final labelStyle = TextStyle(
    fontFamily: "OldStandard",
    fontSize: fontSize * 0.8,
    fontWeight: FontWeight.bold,
    color: scheme.primary,
  );

  return Container(
    key: anchorKey,
    margin: const EdgeInsets.symmetric(vertical: 8.0),
    padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 8.0),
    decoration: BoxDecoration(
      color: scheme.primary.withValues(alpha: 0.10),
      border: Border(left: BorderSide(color: scheme.primary, width: 3.0)),
      borderRadius: const BorderRadius.all(Radius.circular(4.0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            isFirst ? "Начало зачала ($rangesLabel)" : "Зачало, продолжение",
            style: labelStyle,
          ),
        ),
        _plain(verses, fontSize, fontFamily),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(isLast ? "Конец зачала" : "Продолжение ниже", style: labelStyle),
        ),
      ],
    ),
  );
}
