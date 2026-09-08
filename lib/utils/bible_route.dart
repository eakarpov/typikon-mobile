import '../dto/pericope.dart';

/// Куда открывается раздел Библии.
///
/// Аргумент маршрута `/bible` — одна строка, по образцу `/reading`: её собирают из
/// нескольких мест (оглавление, сетка глав, кнопка соседней главы, зачало со
/// страницы дня, закладка), и менять сигнатуру всюду ради Библии не хочется.
/// Формат:
///
///   `matfeya`                        — книга, первая глава;
///   `matfeya/19`                     — глава;
///   `matfeya/6#6:31-6:34,7:9-7:11`   — границы зачала: подсветить и прокрутить.
///
/// Изданий здесь нет намеренно. Выбор изданий — настройка читателя, а не свойство
/// места: попади он в адрес, и каждый из входов обязан был бы его знать и
/// протаскивать. Цена — ссылкой на параллельный вид не поделиться; в приложении
/// ссылками не обмениваются, так что цена невелика.
class BibleTarget {
  final String canonId;
  final int chapter;
  final List<PericopeRange> ranges;

  const BibleTarget({
    required this.canonId,
    required this.chapter,
    this.ranges = const [],
  });

  bool contains(int chapter, int verse) =>
      ranges.any((range) => range.contains(chapter, verse));

  /// Ссылка на зачало обычными словами: «гл. 6, ст. 31–34; гл. 7, ст. 9–11».
  String get rangesLabel => ranges.map((range) => range.label).join("; ");
}

/// Собирает аргумент маршрута.
String bibleRouteArgument(
  String canonId, {
  int chapter = 1,
  List<PericopeRange> ranges = const [],
}) {
  final base = "$canonId/$chapter";
  if (ranges.isEmpty) return base;
  final encoded = ranges
      .map((r) => "${r.chapterFrom}:${r.verseFrom}-${r.chapterTo}:${r.verseTo}")
      .join(",");
  return "$base#$encoded";
}

/// Разбирает аргумент маршрута.
///
/// Две уступки, обе перенесены из `parseReadingArgument` вместе с причиной:
/// неразобравшийся хвост открывает главу целиком, а не роняет экран (открытая не
/// на том месте глава лучше сообщения об ошибке), и если границы заданы, глава
/// берётся из первой из них, а не из пути — зачало часто начинается не в той
/// главе, которую подставил вызывающий.
BibleTarget parseBibleArgument(String raw) {
  final hash = raw.indexOf("#");
  final path = hash == -1 ? raw : raw.substring(0, hash);
  final suffix = hash == -1 ? "" : raw.substring(hash + 1);

  final parts = path.split("/");
  final canonId = parts.isNotEmpty ? parts.first.trim() : "";
  final chapter = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 1 : 1;

  final ranges = _parseRanges(suffix);
  return BibleTarget(
    canonId: canonId,
    chapter: ranges.isEmpty ? chapter : ranges.first.chapterFrom,
    ranges: ranges,
  );
}

List<PericopeRange> _parseRanges(String raw) {
  if (raw.isEmpty) return const [];

  final ranges = <PericopeRange>[];
  for (final piece in raw.split(",")) {
    final bounds = piece.split("-");
    if (bounds.length != 2) return const [];

    final from = _parsePoint(bounds[0]);
    final to = _parsePoint(bounds[1]);
    if (from == null || to == null) return const [];

    ranges.add(PericopeRange(
      chapterFrom: from.$1,
      verseFrom: from.$2,
      chapterTo: to.$1,
      verseTo: to.$2,
    ));
  }
  return ranges;
}

(int, int)? _parsePoint(String raw) {
  final parts = raw.split(":");
  if (parts.length != 2) return null;
  final chapter = int.tryParse(parts[0].trim());
  final verse = int.tryParse(parts[1].trim());
  if (chapter == null || verse == null) return null;
  return (chapter, verse);
}
