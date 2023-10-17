class Reading {
  final String name;
  final String author;
  final String readiness;
  final String content;
  final String? ruLink;
  final String link;
  final String type;
  final String updatedAt;
  final List<String> footnotes;

  const Reading({
    required this.name,
    required this.author,
    required this.content,
    required this.readiness,
    required this.ruLink,
    required this.link,
    required this.type,
    required this.updatedAt,
    required this.footnotes,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    var name = json["name"];
    var author = json["author"];
    var readiness = json["readiness"];
    var content = json["content"];
    var ruLink = json["ruLink"];
    var link = json["link"];
    var type = json["type"];
    var updatedAt = json["updatedAt"];
    return Reading(
      name: name,
      author: author,
      readiness: readiness,
      content: content,
      ruLink: ruLink,
      link: link,
      type: type,
      updatedAt: updatedAt,
      footnotes: [],
    );
  }
}