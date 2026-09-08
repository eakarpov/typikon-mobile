import 'dart:convert';

import '../api/reference.dart';
import '../dto/paged.dart';
import '../dto/reference.dart';
import 'singing.dart' show SearchQueryTooShort;
import 'v2/errors.dart';

/// Сколько знаков нужно словарю. Столько же требует сервер, и держать порог у
/// себя стоит ради того, чтобы не ходить в сеть заведомо зря.
const int minLexemeQueryLength = 3;

Future<Paged<NameIndexEntry>> getNames({String? query, int offset = 0}) async {
  final response = await fetchNames(query: query, offset: offset);
  if (response.statusCode == 200) {
    return Paged.fromJson<NameIndexEntry>(jsonDecode(response.body), NameIndexEntry.fromJson);
  }
  throwV2Error(response, "Не удалось загрузить указатель имён");
}

Future<NameEntry> getName(String name, {required int year, String? born}) async {
  final response = await fetchName(name, year: year, born: born);
  if (response.statusCode == 200) {
    return NameEntry.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось найти это имя");
}

Future<ChronologyAnswer> getChronology(Map<String, String> conditions) async {
  final response = await fetchChronology(conditions);
  if (response.statusCode == 200) {
    return ChronologyAnswer.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось разобрать датировку");
}

Future<Paged<LexemeSummary>> getLexemes(String query, {int offset = 0}) async {
  final trimmed = query.trim();
  if (trimmed.length < minLexemeQueryLength) {
    throw const SearchQueryTooShort(minLexemeQueryLength);
  }

  final response = await fetchLexemes(trimmed, offset: offset);
  if (response.statusCode == 200) {
    return Paged.fromJson<LexemeSummary>(jsonDecode(response.body), LexemeSummary.fromJson);
  }
  throwV2Error(response, "Не удалось выполнить поиск по словарю");
}

Future<Lexeme> getLexeme(String id) async {
  final response = await fetchLexeme(id);
  if (response.statusCode == 200) {
    return Lexeme.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось открыть словарную статью");
}
