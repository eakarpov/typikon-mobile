class CalendarMetaItem {
  final String slug;

  const CalendarMetaItem({
    required this.slug,
  });

  factory CalendarMetaItem.fromJson(Map<String, dynamic> json) {
    return CalendarMetaItem(
      slug: (json["slug"] == null) ? "" : (json["slug"]["text"] == null) ? "" : json["slug"]["text"],
    );
  }
}

class CalendarMeta {
  final int page;
  final int total;
  final List<CalendarMetaItem> list;

  const CalendarMeta({
    required this.page,
    required this.total,
    required this.list,
  });

  factory CalendarMeta.fromJson(Map<String, dynamic> json) {
    var list = json['list'];
    List<CalendarMetaItem> items = List<CalendarMetaItem>.from(
        list
            .map((item) => CalendarMetaItem.fromJson(item))
            .toList()
    );
    return CalendarMeta(
      page: json['page'],
      total: json['total'],
      list: items,
    );
  }
}