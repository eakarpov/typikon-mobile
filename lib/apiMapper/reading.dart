import 'dart:convert';

import '../api/reading.dart';
import '../dto/text.dart';
import 'package:typikon/apiMapper/v2/errors.dart';

/// Текст и день, в который он читается.
///
/// Два запроса идут разом, а не друг за другом: второй от первого не зависит, и
/// ждать его очередью значило удваивать время открытия текста на медленной сети.
///
/// **День — дополнение, и его отказ текста не касается.** Прежде сорвавшийся
/// запрос дня (нет сети, а в кэше лежит только сам текст) ронял всё вместе:
/// человек видел ошибку на месте текста, который у него был.
Future<Reading> getText(String id) async {
  final dayFuture = _dayByText(id);
  final response = await fetchText(id);
  final day = await dayFuture;

  if (response.statusCode == 200) {
    return Reading.fromJson(jsonDecode(response.body), day);
  } else {
    throw Exception('Не получено чтение');
  }
}

Future<Map<String, dynamic>?> _dayByText(String id) async {
  try {
    final response = await fetchDayByText(id);
    if (response.statusCode != 200 || response.body.trim().isEmpty) return null;
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
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
