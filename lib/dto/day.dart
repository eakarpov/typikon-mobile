class DayText {
  final String id;
  final String name;

  const DayText({
    required this.id,
    required this.name,
  });

  factory DayText.fromJson(Map<String, dynamic> json) {
    return DayText(
      id: json["_id"],
      name: json["name"],
    );
  }
}

class DayTextsPart {
  final DayText? text;

  const DayTextsPart({
    required this.text,
  });

  factory DayTextsPart.fromJson(Map<String, dynamic> json) {
    var dayText = json["text"] == null ? null : DayText.fromJson(json["text"]);
    return DayTextsPart(
      text: dayText,
    );
  }
}

class DayTextsParts {
  final List<DayTextsPart>? items;

  const DayTextsParts({
    required this.items,
  });

  factory DayTextsParts.fromJson(Map<String, dynamic> json) {
    var list = json['items'] == null ? [] : json['items'];
    List<DayTextsPart> items = List<DayTextsPart>.from(
        list
            .map((item) => DayTextsPart.fromJson(item))
            .toList()
    );

    return DayTextsParts(
      items: items,
    );
  }
}

class DayTexts {
  final String? name;
  final DayTextsParts? song6;

  const DayTexts({
    required this.name,
    required this.song6,
  });

  factory DayTexts.fromJson(Map<String, dynamic> json) {
    var song6 = json["song6"] == null ? null : DayTextsParts.fromJson(json["song6"]);
    return DayTexts(
      name: json["name"],
      song6: song6,
    );
  }
}

class DayResult {
  final DayTexts? data;

  const DayResult({
    required this.data,
  });

  factory DayResult.fromJson(Map<String, dynamic> json) {
    var day = json["data"] == null ? null : DayTexts.fromJson(json["data"]);
    return DayResult(
      data: day,
    );
  }
}