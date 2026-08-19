class Verse {
  final String id;
  final String textId;
  final int chapter;
  final int verse;
  final String content;

  const Verse({
    required this.id,
    required this.textId,
    required this.chapter,
    required this.verse,
    required this.content,
  });

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      id: json["id"] ?? "",
      textId: json["textId"] ?? "",
      chapter: json["chapter"] is int ? json["chapter"] : int.tryParse("${json["chapter"]}") ?? 0,
      verse: json["verse"] is int ? json["verse"] : int.tryParse("${json["verse"]}") ?? 0,
      content: json["content"] ?? "",
    );
  }
}

class VerseList {
  final List<Verse> list;

  const VerseList({required this.list});

  factory VerseList.fromJson(List<dynamic> json) {
    return VerseList(
      list: List<Verse>.from(json.map((item) => Verse.fromJson(item)).toList()),
    );
  }

  /// Стихи книги, сгруппированные по номеру главы, в порядке появления.
  Map<int, List<Verse>> get byChapter {
    final Map<int, List<Verse>> result = {};
    for (final v in list) {
      result.putIfAbsent(v.chapter, () => []).add(v);
    }
    return result;
  }
}
