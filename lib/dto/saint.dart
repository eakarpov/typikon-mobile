import "package:typikon/dto/text.dart";

class Saint {
  final String? id;
  final List<Reading> texts;
  final List<Reading> mentions;

  const Saint({
    required this.id,
    required this.texts,
    required this.mentions,
  });

  factory Saint.fromJson(String id, List<dynamic> json, List<dynamic> jsonMentions) {
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

    return Saint(
      id: id,
      texts: items,
      mentions: itemsMentions,
    );
  }
}
