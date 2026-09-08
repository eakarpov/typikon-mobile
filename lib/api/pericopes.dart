import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Указатель зачал.
///
/// Раздел доступа `pericopes` бесплатный, ключа не требует — в отличие от
/// поиска, — поэтому и откат в анонимы здесь оставлен как везде.
///
/// Кэшируем щедро: зачала — единица устава, они меняются правкой в админке, а
/// не сами собой.

const int pericopePageSize = 50;

Future<http.Response> fetchPericopes({
  String? source,
  String? book,
  int offset = 0,
}) {
  final query = {
    "limit": "$pericopePageSize",
    if (offset > 0) "offset": "$offset",
    if (source != null && source.isNotEmpty) "source": source,
    if (book != null && book.isNotEmpty) "book": book,
  };

  return cachedFetch(
    pericopesCacheKey(source: source, book: book, offset: offset),
    () => v2Get(v2Uri("/pericopes", query)),
    ttl: const Duration(days: 7),
    isCacheable: (body) => jsonDecode(body) is Map,
  );
}

/// Ключ кэша страницы указателя.
///
/// Пустые отборы записываются как «-», а не пропускаются: иначе «без книги, со
/// смещением 50» и «книга 50, без смещения» после схлопывания разделителей в
/// `_sanitizeKey` дали бы одно имя файла.
String pericopesCacheKey({String? source, String? book, int offset = 0}) =>
    "pericopes:${source?.isNotEmpty == true ? source : "-"}"
    ":${book?.isNotEmpty == true ? book : "-"}:$offset";

Future<http.Response> fetchPericope(String id, {String? lang}) {
  return cachedFetch(
    "pericope:$id:${lang ?? "-"}",
    () => v2Get(v2Uri("/pericopes/$id", lang == null ? null : {"lang": lang})),
    ttl: const Duration(days: 7),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded.containsKey("verses");
    },
  );
}
