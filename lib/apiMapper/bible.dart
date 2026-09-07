import 'dart:convert';

import '../api/bible.dart';
import '../dto/bible.dart';
import 'v2/errors.dart';

/// Разбор ответов Библии.
///
/// Ветка одна: успех разбираем, всё прочее уходит в [throwV2Error], который
/// различает «слишком часто» и «такого нет» и, где может, показывает сообщение
/// сервера вместо нашего общего. Оно точнее: «В этих изданиях такой главы нет» —
/// не ошибка приложения, а честный ответ.

Future<BibleBookList> getBibleBooks() async {
  final response = await fetchBibleBooks();
  if (response.statusCode == 200) {
    return BibleBookList.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось загрузить оглавление Библии");
}

Future<BibleEditionList> getBibleEditions() async {
  final response = await fetchBibleEditions();
  if (response.statusCode == 200) {
    return BibleEditionList.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось загрузить список изданий");
}

Future<BibleChapter> getBibleChapter(
  String canonId,
  int chapter, {
  List<String> editions = const [],
}) async {
  final response = await fetchBibleChapter(canonId, chapter, editions: editions);
  if (response.statusCode == 200) {
    return BibleChapter.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось загрузить главу");
}
