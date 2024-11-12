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

  factory PlaceInfo.fromJson(Map<String, dynamic> json) {
    List<String> synonyms = List<String>.from(json["synonyms"] as List);
    var list = json["links"];
    List<TextLink> items = List<TextLink>.from(
        list
            .map((item) => TextLink.fromJson(item))
            .toList()
    );
    return PlaceInfo(
      id: json["id"],
      name: json["name"],
      description: json["description"],
      synonyms: synonyms,
      links: items,
      latitude: double.parse(json["latitude"]),
      longitude: double.parse(json["longitude"]),
    );
  }
}
