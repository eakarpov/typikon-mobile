import 'dart:convert';

import "package:typikon/dto/saint.dart";
import "package:typikon/api/saints.dart";

Future<Saint> getSaint(String id) async {
  final response = await fetchTextsBySaint(id);
  final responseMentions = await fetchTextsBySaintMention(id);

  if (response.statusCode == 200 && responseMentions.statusCode == 200) {
    return Saint.fromJson(id, jsonDecode(response.body), jsonDecode(responseMentions.body));
  } else {
    throw Exception('Не получены результаты');
  }
}