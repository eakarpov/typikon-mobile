import "package:typikon/dto/day.dart";

class Month {
  final String? id;
  final int ? value;
  final String? alias;
  final int? order;

  const Month({
    required this.id,
    required this.value,
    required this.alias,
    required this.order,
  });

  factory Month.fromJson(Map<String, dynamic> json) {
    return Month(
      id: json["_id"],
      value: json["value"],
      alias: json["alias"],
      order: json["order"],
    );
  }
}

class MonthWithDays {
  final String? id;
  final int? value;
  final String? alias;
  final int? order;
  final List<DayTexts> days;

  const MonthWithDays({
    required this.id,
    required this.value,
    required this.alias,
    required this.order,
    required this.days,
  });

  factory MonthWithDays.fromJson(Map<String, dynamic> json) {
    var list = json["days"];
    List<DayTexts> items = List<DayTexts>.from(
        list
            .map((item) => DayTexts.fromJson(item))
            .toList()
    );
    return MonthWithDays(
      id: json["_id"],
      value: json["value"],
      alias: json["alias"],
      order: json["order"],
      days: items,
    );
  }
}

class MonthList {
  final List<Month> list;

  const MonthList({
    required this.list,
  });

  factory MonthList.fromJson(List<dynamic> json) {
    var list = json;
    List<Month> items = List<Month>.from(
        list
            .map((item) => Month.fromJson(item))
            .toList()
    );
    return MonthList(
      list: items,
    );
  }
}