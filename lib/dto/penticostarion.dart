import "package:typikon/dto/week.dart";

class PenticostarionCollection {
  final List<WeekWithDays> weeks;

  const PenticostarionCollection({
    required this.weeks,
  });

  factory PenticostarionCollection.fromJson(List<dynamic> json) {
    var list = json;
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