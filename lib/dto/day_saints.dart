// Памяти Днеслова и собственного каталога: /api/v2/calendar/{date}/saints.
// partial отличает недоступность источника без снимка от полного пустого дня.

class DaySaint {
  /// Слуг каталога или числовой номер Днеслова; обе формы открывают досье.
  final String slug;
  final String name;

  /// Оплечный образ. Абсолютный адрес cdn.dneslov.org или отсутствует вовсе.
  final String? roundelUrl;

  const DaySaint({required this.slug, required this.name, this.roundelUrl});

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
  final bool partial;
  final bool sourceStale;

  const DaySaints({
    required this.date,
    this.saints = const [],
    this.partial = false,
    this.sourceStale = false,
  });

  static List<T> _list<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parse,
  ) => raw is List
      ? raw.map((item) => parse(item as Map<String, dynamic>)).toList()
      : <T>[];

  factory DaySaints.fromJson(Map<String, dynamic> json) => DaySaints(
    date: json["date"] ?? "",
    saints: _list(json["saints"], DaySaint.fromJson),
    partial: json["partial"] == true,
    sourceStale: json["sourceStale"] == true,
  );
}
