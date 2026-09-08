import "package:typikon/dto/week.dart";

class TriodionCollection {
  final List<WeekWithDays> weeks;

  const TriodionCollection({
    required this.weeks,
  });

  /// Конверт второй версии API или голый список первой.
  factory TriodionCollection.fromJson(dynamic json) {
    final list = json is Map ? (json["items"] as List? ?? const []) : json as List;
    List<WeekWithDays> items = List<WeekWithDays>.from(
        list
            .map((item) => WeekWithDays.fromJson(item))
            .toList()
    );
    return TriodionCollection(
      weeks: items,
    );
  }
}