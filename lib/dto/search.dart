/// Найденный текст.
///
/// Бекенд ищет не по названию, а полнотекстово — по нормализованным копиям
/// названия, описания, содержимого, автора и переводчика (`searchName` /
/// `searchContent`), сортирует по релевантности и возвращает вместе с каждым
/// текстом фрагмент вокруг совпадения. Приложение всё это время забирало из
/// ответа только имя и id.
class SearchBookText {
  final String id;
  final String name;

  /// Фрагмент исходного текста вокруг найденного слова — с ударениями и
  /// церковнославянской графикой, как в самом тексте. Приходит `null`, когда
  /// совпадение было в названии или описании, а не в содержимом.
  final String? snippet;

  /// Описание текста. Показываем вместо фрагмента, когда фрагмента нет:
  /// совпало название — объяснять, что это за текст, всё равно нужно.
  final String? description;

  final String? author;

  const SearchBookText({
    required this.id,
    required this.name,
    this.snippet,
    this.description,
    this.author,
  });

  /// Что показать под названием: фрагмент, если он есть, иначе описание.
  String? get excerpt {
    final value = (snippet != null && snippet!.trim().isNotEmpty) ? snippet : description;
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _nonEmpty(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory SearchBookText.fromJson(Map<String, dynamic> json) {
    return SearchBookText(
      // Ответ содержит и "_id", и приведённый к строке "id" — берём тот, что есть.
      id: (json["id"] ?? json["_id"]).toString(),
      name: json["name"] ?? "",
      snippet: _nonEmpty(json["snippet"]),
      description: _nonEmpty(json["description"]),
      author: _nonEmpty(json["author"]),
    );
  }
}

class SearchResults {
  final List<SearchBookText> texts;

  const SearchResults({
    required this.texts,
  });

  factory SearchResults.fromJson(List<dynamic> json) {
    return SearchResults(
      texts: json.map((item) => SearchBookText.fromJson(item)).toList(),
    );
  }

  factory SearchResults.empty() {
    return const SearchResults(texts: []);
  }
}
