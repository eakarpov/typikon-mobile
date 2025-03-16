import "package:typikon/dto/text.dart";

class DneslovLink {
  final int id;
  final String url;

  const DneslovLink({
    required this.id,
    required this.url,
  });

  factory DneslovLink.fromJson(
      Map<String, dynamic> json,
  ) {
    return DneslovLink(
      id: json["id"] ?? 0,
      url: json["url"] ?? "",
    );
  }
}

class DneslovMemo {
  final String title;
  final String description;

  const DneslovMemo({
    required this.title,
    required this.description,
  });

  factory DneslovMemo.fromJson(
      Map<String, dynamic> json,
  ) {
    return DneslovMemo(
      title: json["title"] ?? "",
      description: json["description"] ?? "",
    );
  }
}

class DneslovMemory {
  final List<DneslovMemo> memoes;
  final List<DneslovLink> links;

  const DneslovMemory({
    required this.memoes,
    required this.links,
  });

  factory DneslovMemory.fromJson(
      Map<String, dynamic> json
  ) {
    var list = json["memoes"];
    List<DneslovMemo> items = List<DneslovMemo>.from(
        list
            .map((item) => DneslovMemo.fromJson(item))
            .toList()
    );
    var links = json["links"] == null ? [] : json["links"];
    List<DneslovLink> linkItems = List<DneslovLink>.from(
        links
            .map((item) => DneslovLink.fromJson(item))
            .toList()
    );

    return DneslovMemory(
      memoes: items,
      links: linkItems,
    );
  }
}

class Saint {
  final String? id;
  final String? slug;
  final List<Reading> texts;
  final List<Reading> mentions;
  final DneslovMemory memory;

  const Saint({
    required this.slug,
    required this.id,
    required this.texts,
    required this.mentions,
    required this.memory,
  });

  factory Saint.fromJson(
      String id,
      String slug,
      List<dynamic> json,
      List<dynamic> jsonMentions,
      Map<String, dynamic> jsonDneslov,
  ) {
    var list = json;
    List<Reading> items = List<Reading>.from(
        list
            .map((item) => Reading.fromJson(item, null))
            .toList()
    );
    var mentions = jsonMentions;
    List<Reading> itemsMentions = List<Reading>.from(
        mentions
            .map((item) => Reading.fromJson(item, null))
            .toList()
    );
    DneslovMemory memory = DneslovMemory.fromJson(jsonDneslov);

    return Saint(
      id: id,
      slug: slug,
      texts: items,
      mentions: itemsMentions,
      memory: memory,
    );
  }
}
