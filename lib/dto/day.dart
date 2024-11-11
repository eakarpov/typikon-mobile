class DayText {
  final String id;
  final String name;
  final String content;

  const DayText({
    required this.id,
    required this.name,
    required this.content,
  });

  factory DayText.fromJson(Map<String, dynamic> json) {
    return DayText(
      id: json["_id"],
      name: json["name"],
      content: json["content"],
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
  final String? id;
  final String? name;
  final DayTextsParts? kathisma1;
  final DayTextsParts? kathisma2;
  final DayTextsParts? kathisma3;
  final DayTextsParts? ipakoi;
  final DayTextsParts? polyeleos;
  final DayTextsParts? song3;
  final DayTextsParts? song6;
  final DayTextsParts? apolutikaTroparia;
  final DayTextsParts? before1h;

  const DayTexts({
    required this.id,
    required this.name,
    required this.kathisma1,
    required this.kathisma2,
    required this.kathisma3,
    required this.ipakoi,
    required this.polyeleos,
    required this.song3,
    required this.song6,
    required this.apolutikaTroparia,
    required this.before1h,
  });

  factory DayTexts.fromJson(Map<String, dynamic> json) {
    var kathisma1 = json["kathisma1"] == null ? null : DayTextsParts.fromJson(json["kathisma1"]);
    var kathisma2 = json["kathisma2"] == null ? null : DayTextsParts.fromJson(json["kathisma2"]);
    var kathisma3 = json["kathisma3"] == null ? null : DayTextsParts.fromJson(json["kathisma3"]);
    var ipakoi = json["ipakoi"] == null ? null : DayTextsParts.fromJson(json["ipakoi"]);
    var polyeleos = json["polyeleos"] == null ? null : DayTextsParts.fromJson(json["polyeleos"]);
    var song3 = json["song3"] == null ? null : DayTextsParts.fromJson(json["song3"]);
    var song6 = json["song6"] == null ? null : DayTextsParts.fromJson(json["song6"]);
    var apolutikaTroparia = json["apolutikaTroparia"] == null ? null : DayTextsParts.fromJson(json["apolutikaTroparia"]);
    var before1h = json["before1h"] == null ? null : DayTextsParts.fromJson(json["before1h"]);
    return DayTexts(
      id: json["id"],
      name: json["name"],
      kathisma1: kathisma1,
      kathisma2: kathisma2,
      kathisma3: kathisma3,
      ipakoi: ipakoi,
      polyeleos: polyeleos,
      song3: song3,
      song6: song6,
      apolutikaTroparia: apolutikaTroparia,
      before1h: before1h,
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