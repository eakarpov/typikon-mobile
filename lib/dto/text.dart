class Reading {
  final String name;
  final String author;
  final String readiness;
  final String content;

  const Reading({
    required this.name,
    required this.author,
    required this.content,
    required this.readiness,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    var name = json["name"];
    var author = json["author"];
    var readiness = json["readiness"];
    var content = json["content"];
    return Reading(
      name: name,
      author: author,
      readiness: readiness,
      content: content,
    );
  }
}