import 'dart:convert';

import "package:typikon/dto/penticostarion.dart";
import "package:typikon/dto/triodion.dart";
import "package:typikon/api/collections.dart";

Future<PenticostarionCollection> getPenticostarion() async {
  final response = await fetchPenticostarion();

  if (response.statusCode == 200) {
    return PenticostarionCollection.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получены результаты');
  }
}

Future<TriodionCollection> getTriodion() async {
  final response = await fetchTriodion();

  if (response.statusCode == 200) {
    return TriodionCollection.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получены результаты');
  }
}

Future<TriodionCollection> getOutTriodion() async {
  final response = await fetchOutTriodion();

  if (response.statusCode == 200) {
    return TriodionCollection.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получены результаты');
  }
}
