class BookText {
  final String name;
  final String id;

  const BookText({
    required this.name,
    required this.id,
  });

  factory BookText.fromJson(Map<String, dynamic> json) {
    return BookText(
      name: json["name"],
      id: json["_id"],
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

  factory BookWithTexts.fromJson(Map<String, dynamic> json) {
    var name = json["name"];
    var author = json["author"];
    var list = json["texts"];
    List<BookText> items = List<BookText>.from(
        list
            .map((item) => BookText.fromJson(item))
            .toList()
    );
    return BookWithTexts(
      texts: items,
      name: name,
      author: author,
    );
  }
}