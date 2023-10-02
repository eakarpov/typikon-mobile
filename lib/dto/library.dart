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
      id: json["_id"],
    );
  }
}

class BookList {
  final List<Book> list;

  const BookList({
    required this.list,
  });

  factory BookList.fromJson(List<dynamic> json) {
    var list = json;
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