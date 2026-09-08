import "package:typikon/dto/week.dart";

class PenticostarionCollection {
  final List<WeekWithDays> weeks;

  const PenticostarionCollection({
    required this.weeks,
  });

  /// Конверт второй версии API или голый список первой.
  factory PenticostarionCollection.fromJson(dynamic json) {
    final list = json is Map ? (json["items"] as List? ?? const []) : json as List;
    List<WeekWithDays> items = List<WeekWithDays>.from(
        list
            .map((item) => WeekWithDays.fromJson(item))
            .toList()
    );
    return PenticostarionCollection(
      weeks: items,
    );
  }
}