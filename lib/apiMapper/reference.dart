import 'dart:convert';

import '../api/reference.dart';
import '../dto/paged.dart';
import '../dto/reference.dart';
import 'singing.dart' show SearchQueryTooShort;
import 'v2/errors.dart';
import '../utils/accents.dart';
import '../utils/selected_word.dart';

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

Future<WordAccents> getWordAccents(String word) async {
  final response = await fetchWordAccents(word);
  if (response.statusCode == 200) {
    return WordAccents.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось узнать ударение");
}

/// Статья словаря для слова, если она есть.
///
/// Ручка ударений называет начальную форму написанием, а не идентификатором
/// статьи, так что статью ищем поиском. Берётся только совпавшая целиком:
/// поиск идёт по началу слова, и «земля» нашла бы заодно «землянъ» — вести
/// туда читателя значило бы подсунуть ему другое слово. Совпадение со знаками
/// первым: «спасти́» и «спа́сти» — два разных глагола.
///
/// Слово под титлом не ищем вовсе: сокращений словарь не знает, а сервер на
/// такой запрос отвечает ошибкой.
Future<String?> findLexemeId(String spelling) async {
  final query = stripAccents(spelling).toLowerCase();
  if (query.length < minLexemeQueryLength || hasTitlo(query)) return null;

  final found = await getLexemes(query);
  for (final item in found.items) {
    if (item.name == spelling) return item.id;
  }
  final key = spellingKey(spelling);
  for (final item in found.items) {
    if (spellingKey(item.name) == key) return item.id;
  }
  return null;
}
