class SearchBookText {
  final String name;
  final String id;

  const SearchBookText({
    required this.name,
    required this.id,
  });

  factory SearchBookText.fromJson(Map<String, dynamic> json) {
    return SearchBookText(
      name: json["name"],
      id: json["_id"],
    );
  }
}

class SearchResults {
  final List<SearchBookText> texts;

  const SearchResults({
    required this.texts,
  });

  factory SearchResults.fromJson(List<dynamic> json) {
    var list = json;
    List<SearchBookText> items = List<SearchBookText>.from(
        list
            .map((item) => SearchBookText.fromJson(item))
            .toList()
    );
    return SearchResults(
      texts: items,
    );
  }

  factory SearchResults.empty() {
    return SearchResults(
      texts: [],
    );
  }
}