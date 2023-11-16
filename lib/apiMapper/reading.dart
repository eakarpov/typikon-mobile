import 'dart:convert';

import '../api/reading.dart';
import '../dto/text.dart';

Future<Reading> getText(String id) async {
  final response = await fetchText(id);

  if (response.statusCode == 200) {
    return Reading.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получено чтение');
  }
}

Future<ReadingList> getLastTexts() async {
  final response = await fetchLastTexts();

  if (response.statusCode == 200) {
    return ReadingList.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получено чтение');
  }
}