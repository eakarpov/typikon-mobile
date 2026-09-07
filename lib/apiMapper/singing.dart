import 'dart:convert';

import '../api/singing.dart';
import '../dto/chant.dart';
import '../dto/incipit.dart';
import '../dto/paged.dart';
import 'v2/errors.dart';

/// Разбор ответов певческого корпуса.
///
/// Сверх общего `throwV2Error` здесь одно своё исключение — на случай, когда
/// корпус на сервере не выложен. Сервер называет этот случай отдельным кодом
/// (`corpus_unavailable`, `503`), и это не поломка приложения: показывать
/// «не удалось выполнить поиск» значило бы принять вину на себя и заставить
/// читателя пробовать снова там, где пробовать нечего.

/// Запрос короче того, что примет сервер.
class SearchQueryTooShort implements Exception {
  const SearchQueryTooShort(this.minLength);

  final int minLength;

  @override
  String toString() => "Введите хотя бы $minLength символа.";
}

/// Корпус певческих текстов на сервере не выложен.
class CorpusUnavailableException implements Exception {
  const CorpusUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

Never _throw(dynamic response, String fallback) {
  if (v2ErrorCode(response) == "corpus_unavailable") {
    throw CorpusUnavailableException(v2ErrorMessage(response, fallback));
  }
  throwV2Error(response, fallback);
}

Future<Paged<Chant>> getChants(String query, {int offset = 0, String? language}) async {
  final trimmed = query.trim();
  if (trimmed.length < minChantQueryLength) {
    throw const SearchQueryTooShort(minChantQueryLength);
  }

  final response = await fetchChants(trimmed, offset: offset, language: language);
  if (response.statusCode == 200) {
    return Paged.fromJson<Chant>(jsonDecode(response.body), Chant.fromJson);
  }
  _throw(response, "Не удалось выполнить поиск по песнопениям");
}

Future<Paged<Incipit>> getIncipits(String query, {int offset = 0, String? language}) async {
  final trimmed = query.trim();
  if (trimmed.length < minIncipitQueryLength) {
    throw const SearchQueryTooShort(minIncipitQueryLength);
  }

  final response = await fetchIncipits(trimmed, offset: offset, language: language);
  if (response.statusCode == 200) {
    return Paged.fromJson<Incipit>(jsonDecode(response.body), Incipit.fromJson);
  }
  _throw(response, "Не удалось найти зачин");
}

Future<IncipitDetail> getIncipit(String language, String incipit) async {
  final response = await fetchIncipit(language, incipit);
  if (response.statusCode == 200) {
    return IncipitDetail.fromJson(jsonDecode(response.body));
  }
  _throw(response, "Не удалось открыть зачин");
}
