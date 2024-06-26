import 'dart:convert';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:built_value/serializer.dart';

class Reading {
  final String id;
  final String name;
  final String? author;
  final String readiness;
  final String content;
  final String? ruLink;
  final String? link;
  final String type;
  final DateTime updatedAt;
  final List<String> footnotes;
  final String? dneslovId;

  const Reading({
    required this.id,
    required this.name,
    required this.author,
    required this.content,
    required this.readiness,
    required this.ruLink,
    required this.link,
    required this.type,
    required this.updatedAt,
    required this.footnotes,
    required this.dneslovId,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    var serializers = (Serializers().toBuilder()..add(Iso8601DateTimeSerializer())).build();
    var specifiedType = const FullType(DateTime);

    var id = json["id"];
    var name = json["name"];
    var author = json["author"];
    var readiness = json["readiness"];
    var content = json["content"];
    var ruLink = json["ruLink"];
    var link = json["link"];
    var type = json["type"];
    var dneslovId = json["dneslovId"];
    var updatedAtString = json["updatedAt"];
    return Reading(
      id: id,
      name: name,
      author: author,
      readiness: readiness,
      content: content,
      ruLink: ruLink,
      link: link,
      type: type,
      updatedAt: (updatedAtString == null) ? DateTime.now() : DateTime.parse(updatedAtString),
      footnotes: [],
      dneslovId: dneslovId,
    );
  }
}

class ReadingList {
  final List<Reading> list;

  const ReadingList({
    required this.list,
  });

  factory ReadingList.fromJson(List<dynamic> json) {
    var list = json;
    List<Reading> items = List<Reading>.from(
        list
            .map((item) => Reading.fromJson(item))
            .toList()
    );
    return ReadingList(
      list: items,
    );
  }
}