import "package:typikon/dto/dneslov/calendarMeta.dart";

class CalendarDayDItem {
  final String? title;
  final String? description;
  final String? happenedAt;
  final String? saintTitle;
  final String slug;
  final int eventId;
  final int id;

  const CalendarDayDItem({
    required this.title,
    required this.description,
    required this.happenedAt,
    required this.saintTitle,
    required this.slug,
    required this.eventId,
    required this.id,
  });

  factory CalendarDayDItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> orders = json["orders"];
    String saintTitle = "";
    for (var key in orders.keys) {
      saintTitle = orders[key];
    }
    var slug = json["slug"];
    var id = json["id"];
    var eventId = json["event_id"];
    return CalendarDayDItem(
      id: id,
      title: json["title"],
      description: json["description"],
      happenedAt: json["happened_at"],
      saintTitle: saintTitle,
      slug: (slug == null) ? "" : slug,
      eventId: (eventId == null) ? 0 : eventId,
    );
  }
}

class CalendarDayD {
  final int page;
  final int total;
  final List<CalendarDayDItem> list;
  final CalendarMeta meta;
  final String calendarString;

  const CalendarDayD({
    required this.page,
    required this.total,
    required this.list,
    required this.meta,
    required this.calendarString,
  });

  factory CalendarDayD.fromJson(Map<String, dynamic> json, CalendarMeta calendarMeta, String calendarString) {
    var list = json['list'];
    List<CalendarDayDItem> items = List<CalendarDayDItem>.from(
        list
            .map((item) => CalendarDayDItem.fromJson(item))
            .toList()
    );
    return CalendarDayD(
      page: json['page'],
      total: json['total'],
      list: items,
      meta: calendarMeta,
      calendarString: calendarString,
    );
  }
}