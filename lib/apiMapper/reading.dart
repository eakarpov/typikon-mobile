import 'dart:convert';

import '../api/reading.dart';
import '../dto/text.dart';
import 'package:typikon/apiMapper/v2/errors.dart';

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
/// Текст с расставленными ударениями.
///
/// Отказ пробрасывается наверх: экран должен вернуть переключатель в книжный вид
/// и сказать, что не вышло, — молча показать книгу значило бы, что человек нажал
/// и ничего не заметил.
Future<AccentedText> getTextAccents(String id) async {
  final response = await fetchTextAccents(id);

  if (response.statusCode == 200) {
    return AccentedText.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }
  throwV2Error(response, 'Не удалось расставить ударения');
}
