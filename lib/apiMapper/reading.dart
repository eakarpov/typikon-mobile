import 'dart:convert';

import '../api/reading.dart';
import '../dto/text.dart';

Future<Reading> getText(String id) async {
  final response = await fetchText(id);
  final responseDay = await fetchDayByText(id);

  if (response.statusCode == 200 && responseDay.statusCode == 200) {
    return Reading.fromJson(jsonDecode(response.body), jsonDecode(responseDay.body));
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