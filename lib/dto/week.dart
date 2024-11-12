import "package:typikon/dto/day.dart";

class WeekWithDays {
  final String? id;
  final String? type;
  final String? label;
  final int? value;
  final String? alias;
  final bool? penticostration;
  final List<DayTexts> days;

  const WeekWithDays({
    required this.id,
    required this.type,
    required this.value,
    required this.label,
    required this.alias,
    required this.penticostration,
    required this.days,
  });

  factory WeekWithDays.fromJson(Map<String, dynamic> json) {
    var list = json["days"];
    List<DayTexts> items = List<DayTexts>.from(
        list
            .map((item) => DayTexts.fromJson(item))
            .toList()
    );
    return WeekWithDays(
      id: json["id"],
      value: json["value"],
      alias: json["alias"],
      label: json["label"],
      type: json["type"],
      penticostration: json["penticostration"],
      days: items,
    );
  }
}
