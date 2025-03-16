import 'dart:convert';

import "package:typikon/dto/saint.dart";
import "package:typikon/api/saints.dart";
import "package:typikon/api/dneslov/memories.dart";

Future<Saint> getSaint(String slugId) async {
  final responseDneslov = await fetchMemoryById(slugId);
  Map<String, dynamic> json = jsonDecode(responseDneslov.body);
  int id = json["id"];
  String slug = json["slug"];

  final response = await fetchTextsBySaint(id.toString());
  final responseMentions = await fetchTextsBySaintMention(id.toString());
  final responseDneslovInfo = await fetchMemoryInfoBySlug(slug);

  if (response.statusCode == 200 && responseMentions.statusCode == 200) {
    return Saint.fromJson(
        id.toString(),
        slug,
        jsonDecode(response.body),
        jsonDecode(responseMentions.body),
        jsonDecode(responseDneslovInfo.body),
    );
  } else {
    throw Exception('Не получены результаты');
  }
}