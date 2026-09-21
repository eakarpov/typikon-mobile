import 'dart:convert';

import '../api/singing.dart' as api;
import '../api/singing.dart';
import '../dto/chant.dart';
import '../dto/corpus.dart';
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

// --- Каноны, акафисты, молитвы -------------------------------------------------
//
// Отказы разбираются тем же `_throw`, что и поиск: невыложенный корпус приходит
// своим кодом и своим исключением, и `errorViewFor` уже умеет не предлагать
// «Повторить» там, где повторять нечего.

Future<FacetedPage<Canon, CanonFacets>> getCanons({
  String? query,
  int offset = 0,
  String? book,
  int? tone,
  String? service,
  String? role,
}) async {
  final response = await api.fetchCanons(
    query: query, offset: offset, book: book, tone: tone, service: service, role: role,
  );
  if (response.statusCode == 200) {
    return FacetedPage.fromJson<Canon, CanonFacets>(
      jsonDecode(response.body), Canon.fromJson, CanonFacets.fromJson,
    );
  }
  _throw(response, "Не удалось открыть каноны");
}

Future<CanonDetail> getCanon(String id) async {
  final response = await api.fetchCanon(id);
  if (response.statusCode == 200) {
    return CanonDetail.fromJson(jsonDecode(response.body));
  }
  _throw(response, "Не удалось открыть канон");
}

Future<FacetedPage<Akathist, AkathistFacets>> getAkathists({
  String? query,
  int offset = 0,
  String? subject,
  String? status,
}) async {
  final response =
      await api.fetchAkathists(query: query, offset: offset, subject: subject, status: status);
  if (response.statusCode == 200) {
    return FacetedPage.fromJson<Akathist, AkathistFacets>(
      jsonDecode(response.body), Akathist.fromJson, AkathistFacets.fromJson,
    );
  }
  _throw(response, "Не удалось открыть акафисты");
}

Future<AkathistDetail> getAkathist(String id) async {
  final response = await api.fetchAkathist(id);
  if (response.statusCode == 200) {
    return AkathistDetail.fromJson(jsonDecode(response.body));
  }
  _throw(response, "Не удалось открыть акафист");
}

Future<FacetedPage<Prayer, PrayerFacets>> getPrayers({
  String? query,
  int offset = 0,
  String? kind,
}) async {
  final response = await api.fetchPrayers(query: query, offset: offset, kind: kind);
  if (response.statusCode == 200) {
    return FacetedPage.fromJson<Prayer, PrayerFacets>(
      jsonDecode(response.body), Prayer.fromJson, PrayerFacets.fromJson,
    );
  }
  _throw(response, "Не удалось открыть молитвы");
}

Future<PrayerDetail> getPrayer(String id) async {
  final response = await api.fetchPrayer(id);
  if (response.statusCode == 200) {
    return PrayerDetail.fromJson(jsonDecode(response.body));
  }
  _throw(response, "Не удалось открыть молитву");
}
