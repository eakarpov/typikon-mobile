import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Места: указатель, карточка, упоминания, стихи, места текста и главы.
///
/// **Набранный запрос не кэшируется вовсе.** `_sanitizeKey` в `cached_fetch`
/// схлопывает всё, кроме латиницы и цифр, в подчёркивания — кириллический запрос
/// превращается в ряд подчёркиваний, и два разных запроса одной длины легли бы в
/// один файл. Так же поступает поиск (`lib/api/search.dart`), а сервер на эти
/// ручки и без того ставит час жизни ответа.
///
/// Адрес места всегда кодируется: в разметке текстов ключом стоит то
/// опознаватель, то прежний псевдоним, и второй бывает каким угодно.

const int placesPageSize = 50;

/// Приставка длины — от столкновения ключей после того же схлопывания: два
/// разных адреса одной длины дали бы одно имя файла (приём из `saints.dart`).
String _key(String prefix, String address) => "$prefix:${address.length}:$address";

Future<http.Response> fetchPlaces({
  String? query,
  String? kind,
  bool scriptureOnly = false,
  int offset = 0,
}) {
  final params = {
    "limit": "$placesPageSize",
    if (offset > 0) "offset": "$offset",
    if (query != null && query.isNotEmpty) "q": query,
    if (kind != null && kind.isNotEmpty) "kind": kind,
    if (scriptureOnly) "scripture": "1",
  };
  Future<http.Response> request() => v2Get(v2Uri("/places", params));

  if (query != null && query.isNotEmpty) return request();

  return cachedFetch(
    placesCacheKey(kind: kind, scriptureOnly: scriptureOnly, offset: offset),
    request,
    ttl: const Duration(days: 7),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded["items"] is List;
    },
  );
}

/// Ключ кэша страницы указателя.
///
/// Пустые отборы записываются как «-», а не пропускаются: иначе «без рода, со
/// смещением 50» и «род 50, без смещения» после схлопывания разделителей дали бы
/// одно имя (приём из `pericopes.dart`).
String placesCacheKey({String? kind, bool scriptureOnly = false, int offset = 0}) =>
    "places:${kind?.isNotEmpty == true ? kind : "-"}"
    ":${scriptureOnly ? "bible" : "-"}:$offset";

Future<http.Response> fetchPlace(String address) {
  return cachedFetch(
    _key("place", address),
    () => v2Get(v2Uri("/places/${Uri.encodeComponent(address)}")),
    ttl: const Duration(hours: 24),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded.containsKey("name");
    },
  );
}

Future<http.Response> fetchPlaceMentions(String address) {
  return cachedFetch(
    _key("place-mentions", address),
    () => v2Get(v2Uri("/places/${Uri.encodeComponent(address)}/mentions")),
    ttl: const Duration(hours: 24),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded.containsKey("scripture");
    },
  );
}

Future<http.Response> fetchPlaceScripture(
  String address, {
  String? book,
  int offset = 0,
}) {
  final params = {
    "limit": "200",
    if (offset > 0) "offset": "$offset",
    if (book != null && book.isNotEmpty) "book": book,
  };

  return cachedFetch(
    "${_key("place-verses", address)}:${book?.isNotEmpty == true ? book : "-"}:$offset",
    () => v2Get(v2Uri("/places/${Uri.encodeComponent(address)}/scripture", params)),
    ttl: const Duration(days: 7),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded["items"] is List;
    },
  );
}

/// Места, названные в тексте чтения.
Future<http.Response> fetchTextPlaces(String textId) {
  return cachedFetch(
    _key("text-places", textId),
    () => v2Get(v2Uri("/texts/${Uri.encodeComponent(textId)}/places")),
    ttl: const Duration(days: 7),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded["items"] is List;
    },
  );
}

/// Места, названные в стихах главы. Номер главы канонический.
Future<http.Response> fetchChapterPlaces(String canonId, int chapter) {
  return cachedFetch(
    "chapter-places:$canonId:$chapter",
    () => v2Get(v2Uri("/bible/${Uri.encodeComponent(canonId)}/$chapter/places")),
    ttl: const Duration(days: 7),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded["items"] is List;
    },
  );
}
