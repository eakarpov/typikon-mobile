class CalendarDayPartItem {
  final String name;
  final String content;

  const CalendarDayPartItem({
    required this.name,
    required this.content,
  });

  factory CalendarDayPartItem.fromJson(Map<String, dynamic> json) {
    var text = json == null ? null : json["text"];
    var name = text == null ? "" : text["name"];
    var content = text == null ? "" : text["content"];
    return CalendarDayPartItem(
      name: name,
      content: content,
    );
  }
}

class CalendarDayPart {
  final List<CalendarDayPartItem>? items;

  const CalendarDayPart({
    required this.items,
  });

  factory CalendarDayPart.fromJson(Map<String, dynamic> json) {
    var list = json == null ? [] : json["items"] == null ? [] : json["items"];
    List<CalendarDayPartItem> items = List<CalendarDayPartItem>.from(
        list
            .map((item) => CalendarDayPartItem.fromJson(item))
            .toList()
    );
    return CalendarDayPart(
      items: items,
    );
  }
}

class CalendarDay {
  final CalendarDayPart? kathisma1;
  final CalendarDayPart? kathisma2;
  final CalendarDayPart? kathisma3;
  final CalendarDayPart? ipakoi;
  final CalendarDayPart? polyeleos;
  final CalendarDayPart? song3;
  final CalendarDayPart? song6;
  final CalendarDayPart? apolutikaTroparia;
  final CalendarDayPart? before1h;

  const CalendarDay({
    required this.kathisma1,
    required this.kathisma2,
    required this.kathisma3,
    required this.ipakoi,
    required this.polyeleos,
    required this.song3,
    required this.song6,
    required this.apolutikaTroparia,
    required this.before1h,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    final day = json["day"];
    return CalendarDay(
      kathisma1: day == null ? null : day['kathisma1'] == null ? null : CalendarDayPart.fromJson(day["kathisma1"]),
      kathisma2: day == null ? null : day['kathisma2'] == null ? null : CalendarDayPart.fromJson(day["kathisma2"]),
      kathisma3: day == null ? null : day['kathisma3'] == null ? null : CalendarDayPart.fromJson(day["kathisma3"]),
      ipakoi: day == null ? null : day['ipakoi'] == null ? null : CalendarDayPart.fromJson(day["ipakoi"]),
      polyeleos: day == null ? null : day['polyeleos'] == null ? null : CalendarDayPart.fromJson(day["polyeleos"]),
      song3: day == null ? null : day['song3'] == null ? null : CalendarDayPart.fromJson(day["song3"]),
      song6: day == null ? null : day['song6'] == null ? null : CalendarDayPart.fromJson(day["song6"]),
      apolutikaTroparia: day == null ? null : day['apolutikaTroparia'] == null ? null : CalendarDayPart.fromJson(day["apolutikaTroparia"]),
      before1h: day == null ? null : day['before1h'] == null ? null : CalendarDayPart.fromJson(day["before1h"]),
    );
  }
}