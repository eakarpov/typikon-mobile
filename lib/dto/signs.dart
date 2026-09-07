class Sign {
  final String? id;
  final String? name;
  final String? source;

  /// Ссылка на место в источнике (обычно Типикон на azbyka.ru).
  final String? sourceUrl;
  final String? sign;

  /// Знак стоит в Типиконе с оговоркой ("аще изволит настоятель" и т. п.).
  final bool signConditional;
  final int? date;
  final int? month;

  const Sign({
    required this.id,
    required this.name,
    required this.source,
    required this.sourceUrl,
    required this.sign,
    required this.signConditional,
    required this.date,
    required this.month,
  });

  factory Sign.fromJson(Map<String, dynamic> json) {
    return Sign(
      name: json["name"],
      date: json["date"],
      month: json["month"],
      sign: json["sign"],
      source: json["source"],
      sourceUrl: json["sourceUrl"],
      signConditional: json["signConditional"] == true,
      // Сервер отдаёт id, а не _id: по "_id" здесь всегда приходил null.
      id: json["id"] ?? json["_id"],
    );
  }
}

/// Страница списка памятей. Ответ сервера постраничный и размер страницы
/// задаёт он сам (сейчас 20), поэтому [pageSize] читаем из ответа, а не
/// держим своей константой.
class SignsList {
  final List<Sign> list;
  final int total;
  final int page;
  final int pageSize;

  const SignsList({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// Есть ли что грузить после этой страницы.
  bool get hasMore => page * pageSize < total;

  /// Принимает и объект {items, total, page, pageSize}, и голый список.
  ///
  /// Голый список — форма прежних версий API: страница памятей падала именно
  /// потому, что разбирала только его, а сервер уже отдавал объект.
  factory SignsList.fromJson(dynamic json) {
    if (json is List) {
      final items = json.map<Sign>((item) => Sign.fromJson(item)).toList();
      return SignsList(list: items, total: items.length, page: 1, pageSize: items.length);
    }
    final map = json as Map<String, dynamic>;
    final rawItems = map["items"];
    final items = rawItems is List
        ? rawItems.map<Sign>((item) => Sign.fromJson(item)).toList()
        : <Sign>[];
    int asInt(dynamic value, int fallback) =>
        value is int ? value : int.tryParse("$value") ?? fallback;
    return SignsList(
      list: items,
      total: asInt(map["total"], items.length),
      page: asInt(map["page"], 1),
      pageSize: asInt(map["pageSize"], items.isEmpty ? 1 : items.length),
    );
  }
}
