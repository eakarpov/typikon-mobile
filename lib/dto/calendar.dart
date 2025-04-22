class CalendarDayPartItem {
  final String name;
  final String content;
  final String id;

  const CalendarDayPartItem({
    required this.name,
    required this.content,
    required this.id,
  });

  factory CalendarDayPartItem.fromJson(Map<String, dynamic> json) {
    var text = json == null ? null : json["text"];
    var name = text == null ? "" : text["name"];
    var content = text == null ? "" : text["content"];
    var id = text == null ? "" : text["_id"];
    return CalendarDayPartItem(
      name: name,
      content: content,
      id: id,
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
  final String name;
  final CalendarDayPart? kathisma1;
  final CalendarDayPart? kathisma2;
  final CalendarDayPart? kathisma3;
  final CalendarDayPart? before50;
  final CalendarDayPart? ipakoi;
  final CalendarDayPart? polyeleos;
  final CalendarDayPart? song3;
  final CalendarDayPart? song6;
  final CalendarDayPart? apolutikaTroparia;
  final CalendarDayPart? before1h;
  final CalendarDayPart? h3;
  final CalendarDayPart? h6;
  final CalendarDayPart? h9;

  const CalendarDay({
    required this.name,
    required this.kathisma1,
    required this.kathisma2,
    required this.kathisma3,
    required this.before50,
    required this.ipakoi,
    required this.polyeleos,
    required this.song3,
    required this.song6,
    required this.apolutikaTroparia,
    required this.before1h,
    required this.h3,
    required this.h6,
    required this.h9,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    final day = json["day"];
    print(day["before50"]);
    return CalendarDay(
      name: day == null ? null : day['name'] == null ? "" : day['name'],
      kathisma1: day == null ? null : day['kathisma1'] == null ? null : CalendarDayPart.fromJson(day["kathisma1"]),
      kathisma2: day == null ? null : day['kathisma2'] == null ? null : CalendarDayPart.fromJson(day["kathisma2"]),
      kathisma3: day == null ? null : day['kathisma3'] == null ? null : CalendarDayPart.fromJson(day["kathisma3"]),
      before50: day == null ? null : day['before50'] == null ? null : CalendarDayPart.fromJson(day["before50"]),
      ipakoi: day == null ? null : day['ipakoi'] == null ? null : CalendarDayPart.fromJson(day["ipakoi"]),
      polyeleos: day == null ? null : day['polyeleos'] == null ? null : CalendarDayPart.fromJson(day["polyeleos"]),
      song3: day == null ? null : day['song3'] == null ? null : CalendarDayPart.fromJson(day["song3"]),
      song6: day == null ? null : day['song6'] == null ? null : CalendarDayPart.fromJson(day["song6"]),
      apolutikaTroparia: day == null ? null : day['apolutikaTroparia'] == null ? null : CalendarDayPart.fromJson(day["apolutikaTroparia"]),
      before1h: day == null ? null : day['before1h'] == null ? null : CalendarDayPart.fromJson(day["before1h"]),
      h3: day == null ? null : day['h3'] == null ? null : CalendarDayPart.fromJson(day["h3"]),
      h6: day == null ? null : day['h6'] == null ? null : CalendarDayPart.fromJson(day["h6"]),
      h9: day == null ? null : day['h9'] == null ? null : CalendarDayPart.fromJson(day["h9"]),
    );
  }
}