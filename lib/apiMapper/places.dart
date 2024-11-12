import 'dart:convert';

import "package:typikon/dto/place.dart";
import "package:typikon/api/places.dart";

Future<PlaceInfo> getPlace(String id) async {
  final response = await fetchPlace(id);

  if (response.statusCode == 200) {
    return PlaceInfo.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получены результаты');
  }
}