class Book {
  final String? name;
  final String? author;
  final String? id;

  const Book({
    required this.name,
    required this.author,
    required this.id,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      name: json["name"],
      author: json["author"],
      // Вторая версия API зовёт его `id`; `_id` остаётся понятным ради ответов
      // прежней версии, лежащих в кэше сутками.
      id: json["id"] ?? json["_id"],
    );
  }
}

class BookList {
  final List<Book> list;

  const BookList({
    required this.list,
  });

  /// Конверт второй версии API или голый список первой.
  factory BookList.fromJson(dynamic json) {
    final list = json is Map ? (json["items"] as List? ?? const []) : json as List;
    List<Book> items = List<Book>.from(
        list
            .map((item) => Book.fromJson(item))
            .toList()
    );
    return BookList(
      list: items,
    );
  }
}