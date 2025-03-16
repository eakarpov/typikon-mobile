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
      name: json["name"],
      id: json["_id"] == null ? json["id"] : json["_id"],
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


  factory BookWithTexts.fromJsonToList(List<dynamic> json) {
    var list = json;
    List<BookText> items = List<BookText>.from(
        list
            .map((item) => BookText.fromJson(item))
            .toList()
    );
    return BookWithTexts(
      texts: items,
      name: "",
      author: "",
    );
  }
}