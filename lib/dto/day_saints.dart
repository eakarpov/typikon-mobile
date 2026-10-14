// Святые дня из нашего каталога.
//
// Ответ `/api/v2/calendar/{date}/saints`. Это НЕ месяцеслов Типикона (он — в
// dto/calendar.dart, поле `memories`): здесь — записи каталога святцев,
// связанные с памятями дня. Связи выверены ещё не все, поэтому пустой день —
// нормальное состояние, а не отказ.

class DaySaint {
  /// Наш слуг — по нему открывается досье святого (`/saints`).
  final String slug;
  final String name;

  /// Оплечный образ. Абсолютный адрес cdn.dneslov.org или отсутствует вовсе.
  final String? roundelUrl;

  const DaySaint({
    required this.slug,
    required this.name,
    this.roundelUrl,
  });

  factory DaySaint.fromJson(Map<String, dynamic> json) => DaySaint(
        slug: json["slug"] ?? "",
        name: json["name"] ?? "",
        roundelUrl: json["roundelUrl"],
      );
}

class DaySaints {
  /// День, на который ответ, в виде `yyyy-MM-dd` — как шли за ним.
  final String date;

  final List<DaySaint> saints;

  const DaySaints({
    required this.date,
    this.saints = const [],
  });

  static List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) parse) =>
      raw is List ? raw.map((item) => parse(item as Map<String, dynamic>)).toList() : <T>[];

  factory DaySaints.fromJson(Map<String, dynamic> json) => DaySaints(
        date: json["date"] ?? "",
        saints: _list(json["saints"], DaySaint.fromJson),
      );
}
