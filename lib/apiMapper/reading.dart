import 'dart:convert';

import '../api/reading.dart';
import '../dto/text.dart';

Future<Reading> getText(String id) async {
  final response = await fetchText(id);
  final responseDay = await fetchDayByText(id);

  if (response.statusCode == 200) {
    int contentLength = responseDay.contentLength ?? -1;
    return Reading.fromJson(
      jsonDecode(response.body),
      contentLength > 0 ? jsonDecode(responseDay.body): null,
    );
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