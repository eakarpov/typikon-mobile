import 'package:flutter/material.dart';

import '../dto/pericope.dart';
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

/// Начинается ли зачало этим стихом — то есть нет ли в нём ничего раньше.
bool startsPericope(List<PericopeRange> ranges, int chapter, int verse) =>
    ranges.isNotEmpty &&
    _position(chapter, verse) <=
        _position(ranges.first.chapterFrom, ranges.first.verseFrom);

/// Кончается ли зачало этим стихом.
bool endsPericope(List<PericopeRange> ranges, int chapter, int verse) =>
    ranges.isNotEmpty &&
    _position(chapter, verse) >=
        _position(ranges.last.chapterTo, ranges.last.verseTo);

/// Рамка вокруг куска зачала: подложка, полоса слева и подписи.
///
/// Вынесена отдельно, потому что нужна двум видам сразу — сплошному тексту
/// одного издания и построчному чередованию нескольких. Читатель, пришедший со
/// страницы дня, вправе увидеть границы чтения в обоих: сличать зачало он идёт
/// не реже, чем читать его.
Widget pericopeFrame(
  BuildContext context, {
  required Widget child,
  required String rangesLabel,
  required double fontSize,
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
        child,
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(isLast ? "Конец зачала" : "Продолжение ниже", style: labelStyle),
        ),
      ],
    ),
  );
}

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

  final blocks = <Widget>[];
  for (final run in splitVerseRuns(verses, ranges)) {
    if (!run.inPericope) {
      blocks.add(_plain(run.verses, fontSize, fontFamily));
      continue;
    }

    final first = startsPericope(ranges, run.verses.first.chapter, run.verses.first.verse);
    final last = endsPericope(ranges, run.verses.last.chapter, run.verses.last.verse);

    blocks.add(pericopeFrame(
      context,
      child: _plain(run.verses, fontSize, fontFamily),
      rangesLabel: rangesLabel,
      fontSize: fontSize,
      isFirst: first,
      isLast: last,
      anchorKey: first ? firstKey : null,
    ));
  }
  return blocks;
}

Widget _plain(List<PericopeVerse> verses, double fontSize, String fontFamily) =>
    VerseListView(verses: verses, fontSize: fontSize, fontFamily: fontFamily);

class VerseRun {
  final List<PericopeVerse> verses;
  final bool inPericope;

  const VerseRun(this.verses, this.inPericope);
}

/// Режет подряд идущие стихи на куски внутри и вне зачала.
///
/// Границ может быть несколько (разорванное зачало), и они могут переходить
/// через границу главы, поэтому куски считаются по всей книге разом — иначе не
/// разметить, где зачало действительно началось, а где кончилось.
/// Нарезка стихов на куски внутри и вне зачала.
///
/// Берёт границы, а не адрес: границам всё равно, откуда они приехали, и одна и
/// та же нарезка годится и сплошному тексту, и построчному чередованию.
List<VerseRun> splitVerseRuns(List<PericopeVerse> verses, List<PericopeRange> ranges) {
  final runs = <VerseRun>[];
  if (verses.isEmpty) return runs;
  if (ranges.isEmpty) return [VerseRun(verses, false)];

  bool inside(PericopeVerse verse) =>
      ranges.any((range) => range.contains(verse.chapter, verse.verse));

  var runStart = 0;
  var runInside = inside(verses.first);
  for (var i = 1; i <= verses.length; i++) {
    final inside0 = i < verses.length && inside(verses[i]);
    if (i < verses.length && inside0 == runInside) continue;
    runs.add(VerseRun(verses.sublist(runStart, i), runInside));
    runStart = i;
    runInside = inside0;
  }
  return runs;
}
