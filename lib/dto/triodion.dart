import "package:typikon/dto/week.dart";

class TriodionCollection {
  final List<WeekWithDays> weeks;

  const TriodionCollection({
    required this.weeks,
  });

  factory TriodionCollection.fromJson(List<dynamic> json) {
    var list = json;
    print(json);
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