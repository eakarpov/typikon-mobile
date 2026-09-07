import 'package:typikon/dto/pericope.dart';

/// Куда и на что открывается страница текста.
///
/// Аргумент маршрута "/reading" — одна строка, потому что так его дёргают из
/// десятка мест и менять сигнатуру везде ради зачал не хотелось. Формат:
///
///   `<textId>`                      — просто текст;
///   `<textId>#3`                    — старый вид: прокрутить к главе 3;
///   `<textId>#6:31-6:34,7:9-7:11`   — границы зачала: подсветить и прокрутить.
class ReadingTarget {
  final String textId;
  final List<PericopeRange> ranges;

  /// Глава, к которой надо прокрутить, если границ нет (прежний формат).
  final int? chapter;

  const ReadingTarget({
    required this.textId,
    this.ranges = const [],
    this.chapter,
  });

  /// К какой главе прокручивать в любом случае.
  int? get anchorChapter => ranges.isEmpty ? chapter : ranges.first.chapterFrom;

  /// Ссылка на зачало обычными словами: "гл. 6, ст. 31–34; гл. 7, ст. 9–11".
  String get rangesLabel => ranges.map((r) => r.label).join("; ");

  bool contains(int chapter, int verse) => ranges.any((r) => r.contains(chapter, verse));
}

/// Собирает аргумент маршрута. Без границ и без главы — просто id текста,
/// чтобы не плодить хвост там, где подсвечивать нечего.
String readingRouteArgument(String textId, {List<PericopeRange> ranges = const []}) {
  if (ranges.isEmpty) return textId;
  final encoded = ranges
      .map((r) => "${r.chapterFrom}:${r.verseFrom}-${r.chapterTo}:${r.verseTo}")
      .join(",");
  return "$textId#$encoded";
}

ReadingTarget parseReadingArgument(String raw) {
  final hash = raw.indexOf('#');
  if (hash < 0) return ReadingTarget(textId: raw);

  final textId = raw.substring(0, hash);
  final suffix = raw.substring(hash + 1);
  if (!suffix.contains(':')) {
    return ReadingTarget(textId: textId, chapter: int.tryParse(suffix));
  }

  final ranges = <PericopeRange>[];
  for (final part in suffix.split(',')) {
    final bounds = part.split('-');
    if (bounds.length != 2) continue;
    final from = _parsePoint(bounds[0]);
    final to = _parsePoint(bounds[1]);
    if (from == null || to == null) continue;
    ranges.add(PericopeRange(
      chapterFrom: from[0],
      verseFrom: from[1],
      chapterTo: to[0],
      verseTo: to[1],
    ));
  }
  // Границы не разобрались — открываем текст целиком, это лучше, чем ошибка.
  if (ranges.isEmpty) return ReadingTarget(textId: textId);
  return ReadingTarget(textId: textId, ranges: ranges);
}

List<int>? _parsePoint(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final chapter = int.tryParse(parts[0]);
  final verse = int.tryParse(parts[1]);
  if (chapter == null || verse == null) return null;
  return [chapter, verse];
}

/// Подряд идущие стихи с общим признаком "внутри зачала".
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
/// Берёт границы, а не цель маршрута: границам всё равно, откуда они приехали, а
/// `ReadingTarget` тянет за собой `textId`, которого у главы Библии нет вовсе.
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
