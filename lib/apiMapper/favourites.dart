import 'dart:convert';

import "package:typikon/api/favourites.dart" as api;
import "package:typikon/apiMapper/library.dart";
import "package:typikon/apiMapper/session.dart";
import "package:typikon/dto/book.dart";

/// Избранное: список идентификаторов на сервере и сами тексты для показа.
///
/// Имена текстов сервер отдаёт вместе со списком, но страница избранного
/// показывает их той же карточкой, что и библиотека, поэтому тексты
/// догружаются пакетным запросом — как было и раньше.

/// Список текстов пользователя с сервера, новые сверху.
Future<List<String>> fetchFavouriteIds() async {
  final response = await withSession(api.fetchFavourites);
  if (response.statusCode != 200) {
    throw Exception('Не получено избранное (${response.statusCode})');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! List) return [];
  return decoded
      .map((item) => item is Map ? item["textId"] : null)
      .whereType<String>()
      .toList();
}

Future<void> pushFavourite(String textId, {required bool isAdd}) async {
  final response = await withSession(
    () => isAdd ? api.addFavourite(textId) : api.removeFavourite(textId),
  );
  if (response.statusCode != 200) {
    throw Exception('Избранное не сохранено (${response.statusCode})');
  }
}

/// Вливает локальный список в серверный при первом входе и возвращает
/// объединённый.
Future<List<String>> mergeFavourites(List<String> textIds) async {
  final response = await withSession(() => api.mergeFavourites(textIds));
  if (response.statusCode != 200) {
    throw Exception('Избранное не перенесено (${response.statusCode})');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! List) return textIds;
  return decoded
      .map((item) => item is Map ? item["textId"] : null)
      .whereType<String>()
      .toList();
}

/// Тексты для страницы избранного.
Future<BookWithTexts> getFavouriteTexts(List<String> textIds) {
  return getBatchTexts(textIds);
}
