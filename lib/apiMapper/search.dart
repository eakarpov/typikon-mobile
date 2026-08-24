import 'dart:convert';

import "package:typikon/api/search.dart";
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

  // 400 от бекенда приходит без тела, и единственная его штатная причина —
  // слишком короткий запрос, который мы отсекли выше.
  if (response.statusCode == 400) {
    throw const SearchQueryTooShortException();
  }
  if (response.statusCode != 200) {
    throw Exception('Не получены результаты (${response.statusCode})');
  }

  return SearchResults.fromJson(jsonDecode(response.body)).texts;
}
