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
      // Вторая версия API зовёт его `id`; `_id` остаётся понятным на случай
      // ответа из старого кэша на диске — он живёт неделю.
      id: json["id"] ?? json["_id"],
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
      id: json["id"] ?? json["_id"],
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

  /// Вторая версия API отдаёт перечни конвертом `{items, total, limit, offset}`,
  /// а первая отдавала голым списком. Принимаем и то и другое: на диске может
  /// лежать ответ, записанный прежней версией приложения, и кэш месяцев живёт
  /// неделю.
  factory MonthList.fromJson(dynamic json) {
    final list = json is Map ? (json["items"] as List? ?? const []) : json as List;
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