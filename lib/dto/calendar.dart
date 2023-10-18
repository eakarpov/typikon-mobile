class CalendarDayItem {
  final String? title;
  final String? description;
  final String? happenedAt;
  final String? saintTitle;

  const CalendarDayItem({
    required this.title,
    required this.description,
    required this.happenedAt,
    required this.saintTitle,
  });

  factory CalendarDayItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> orders = json["orders"];
    String saintTitle = "";
    for (var key in orders.keys) {
      saintTitle = orders[key];
    }
    return CalendarDayItem(
      title: json["title"],
      description: json["description"],
      happenedAt: json["happened_at"],
      saintTitle: saintTitle,
    );
  }
}

class CalendarDay {
  final int page;
  final int total;
  final List<CalendarDayItem> list;

  const CalendarDay({
    required this.page,
    required this.total,
    required this.list,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    print(json);
    var list = json['list'] == null ? [] : json["list"];
    List<CalendarDayItem> items = List<CalendarDayItem>.from(
        list
        .map((item) => CalendarDayItem.fromJson(item))
        .toList()
    );
    return CalendarDay(
      page: json['page'] == null ? 0 : json['page'],
      total: json['total'] == null ? 0 : json['total'],
      list: items,
    );
  }
}