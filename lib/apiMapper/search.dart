import 'dart:convert';

import "package:typikon/api/search.dart";
import "package:typikon/apiMapper/v2/errors.dart";
import "package:typikon/dto/search.dart";

/// Запрос короче [minSearchQueryLength] — не ошибка сети и не пустая выдача,
/// а подсказка пользователю; страница показывает её отдельным сообщением.
class SearchQueryTooShortException implements Exception {
  const SearchQueryTooShortException();

  @override
  String toString() => "SearchQueryTooShortException";
}

Future<List<SearchBookText>> getSearchResult(String? query) async {
  final trimmed = query?.trim() ?? "";
  if (trimmed.isEmpty) return SearchResults.empty().texts;
  if (trimmed.length < minSearchQueryLength) {
    throw const SearchQueryTooShortException();
  }

  final response = await searchString(trimmed);

  // Единственная штатная причина отказа по запросу — слишком короткий, и его мы
  // отсекли выше. Прочее — не про запрос.
  if (response.statusCode == 400) {
    throw const SearchQueryTooShortException();
  }
  if (response.statusCode != 200) {
    // Вторая версия API называет причину сама: раздел не дан по ключу, слишком
    // часто, корпус недоступен. Прежде всё это сводилось к «не получены
    // результаты (403)» — числу, которое читателю не говорит ничего.
    throwV2Error(response, 'Не удалось выполнить поиск');
  }

  return SearchResults.fromJson(jsonDecode(utf8.decode(response.bodyBytes))).texts;
}
