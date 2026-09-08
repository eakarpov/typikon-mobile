class TextLink {
  final String? text;
  final String? url;

  const TextLink({
    required this.url,
    required this.text,
  });

  factory TextLink.fromJson(Map<String, dynamic> json) {
    return TextLink(
      text: json["text"],
      url: json["url"],
    );
  }
}

class PlaceInfo {
  final String? id;
  final String? name;
  final String? description;
  final List<String> synonyms;
  final List<TextLink> links;
  final double? latitude;
  final double? longitude;

  const PlaceInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.synonyms,
    required this.links,
    required this.latitude,
    required this.longitude,
  });

  /// Координата: числом, строкой или её отсутствием.
  ///
  /// В базе они лежат строками, вторая версия API приводит их к числу, а места
  /// без точки бывают и вовсе — у пустыни Иорданской её нет. Прежде здесь стоял
  /// `double.parse`, и первое же такое место роняло бы карточку целиком.
  static double? _coordinate(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  factory PlaceInfo.fromJson(Map<String, dynamic> json) {
    final synonyms = json["synonyms"] is List
        ? List<String>.from((json["synonyms"] as List).whereType<String>())
        : const <String>[];
    final links = json["links"] is List
        ? (json["links"] as List)
            .whereType<Map>()
            .map((item) => TextLink.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : const <TextLink>[];

    return PlaceInfo(
      id: json["id"] ?? json["_id"],
      name: json["name"],
      description: json["description"],
      synonyms: synonyms,
      links: links,
      latitude: _coordinate(json["latitude"]),
      longitude: _coordinate(json["longitude"]),
    );
  }
}
