class BookText {
  final String name;
  final String id;
  final String dneslovId;
  final String? textType; // don't know why this is needed

  const BookText({
    required this.name,
    required this.id,
    required this.dneslovId,
    required this.textType,
  });

  factory BookText.fromJson(Map<String, dynamic> json) {
    return BookText(
      name: json["name"] ?? "",
      id: json["id"] ?? json["_id"] ?? "",
      dneslovId: json["dneslovId"] == null ? "" : json["dneslovId"],
      textType: json["type"] == null ? "" : json["type"],
    );
  }

}

class BookWithTexts {
  final List<BookText> texts;
  final String name;
  final String author;

  const BookWithTexts({
    required this.texts,
    required this.name,
    required this.author,
  });

  /// Тексты книги приходят конвертом `{items, total, limit, offset}` во второй
  /// версии API и голым списком в первой. Принимаем оба: кэш книги живёт сутки,
  /// и на диске может лежать ответ, записанный прежней версией приложения.
  static List<BookText> _texts(dynamic raw) {
    final list = raw is Map ? (raw["items"] as List? ?? const []) : (raw as List? ?? const []);
    return list
        .whereType<Map>()
        .map((item) => BookText.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  factory BookWithTexts.fromJson(Map<String, dynamic> json) => BookWithTexts(
        texts: _texts(json["texts"]),
        name: json["name"] ?? "",
        // Вторая версия API отдаёт `null` там, где первая клала пустую строку:
        // автора у книги может не быть вовсе.
        author: json["author"] ?? "",
      );

  /// Тексты, спрошенные поимённо, — без книги: у избранного книги и нет, а
  /// имена его текстов из разных книг.
  factory BookWithTexts.fromJsonToList(dynamic json) =>
      BookWithTexts(texts: _texts(json), name: "", author: "");
}