import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Справочные разделы: именины, хронология, словарь.
///
/// Все три бесплатны по доступу — ключа не требуют, — поэтому и откат в анонимы
/// оставлен как везде.

const int referencePageSize = 50;

bool _isObject(String body) => jsonDecode(body) is Map;

// --- Именины -----------------------------------------------------------------

/// Указатель имён. Меняется не сам собой, а пересборкой указателя скриптом,
/// поэтому держим долго.
Future<http.Response> fetchNames({String? query, int offset = 0}) {
  final trimmed = (query ?? "").trim();
  return cachedFetch(
    "imeniny:${trimmed.isEmpty ? "-" : trimmed}:${trimmed.length}:$offset",
    () => v2Get(v2Uri("/imeniny", {
      "limit": "$referencePageSize",
      if (offset > 0) "offset": "$offset",
      if (trimmed.isNotEmpty) "q": trimmed,
    })),
    ttl: const Duration(days: 7),
    isCacheable: _isObject,
  );
}

/// Кого поминают под этим именем.
///
/// Год входит и в запрос, и в ключ кэша: подвижные памяти в другой год придутся
/// на другое число, и ответ прошлого года был бы неверен молча.
Future<http.Response> fetchName(String name, {required int year, String? born}) {
  return cachedFetch(
    "imeniny:name:${name.length}:$name:$year:${born ?? "-"}",
    () => v2Get(v2Uri("/imeniny/${Uri.encodeComponent(name)}", {
      "year": "$year",
      if (born != null && born.isNotEmpty) "born": born,
    })),
    ttl: const Duration(days: 30),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded.containsKey("memories");
    },
  );
}

// --- Хронология ---------------------------------------------------------------

/// Разбор летописной датировки.
///
/// Не кэшируем: ответ зависит от набора условий целиком, повторяют его редко, а
/// счёт на сервере дешёвый — база тут не участвует вовсе.
Future<http.Response> fetchChronology(Map<String, String> conditions) {
  return v2Get(v2Uri("/chronology", conditions));
}

// --- Словарь ------------------------------------------------------------------

/// Поиск по словарю. Не кэшируем — это поиск.
Future<http.Response> fetchLexemes(String query, {int offset = 0}) {
  return v2Get(v2Uri("/dictionary", {
    "q": query,
    "limit": "$referencePageSize",
    if (offset > 0) "offset": "$offset",
  }));
}

/// Словарная статья: слово и его парадигма. Меняется правкой в словаре.
Future<http.Response> fetchLexeme(String id) {
  return cachedFetch(
    "lexeme:$id",
    () => v2Get(v2Uri("/dictionary/$id")),
    ttl: const Duration(days: 30),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded.containsKey("paradigms");
    },
  );
}
