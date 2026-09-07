import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Поиск по певческому корпусу: песнопения и указатель зачинов.
///
/// Обе ручки живут в разделе доступа `search` — единственном, который анониму не
/// полагается вовсе. Поэтому ходим с `retryAnonymously: false`: повторять запрос
/// без ключа бессмысленно, а метить ключ негодным из-за ручки, которая его и не
/// приняла бы, — вредно.
///
/// Обе живут ещё и на отдельном файле корпуса, которого на сервере может не
/// быть; тогда приходит `503` с кодом `corpus_unavailable`.

/// Сервер отвергает запрос короче трёх знаков, объясняя это в теле ответа.
/// Держим порог и у себя, чтобы не ходить в сеть заведомо зря.
const int minChantQueryLength = 3;

/// У указателя зачинов минимума нет, и это его свойство, а не недосмотр:
/// указатель тем и ценен, что листается по одной букве.
const int minIncipitQueryLength = 1;

/// Сколько строк просим за раз. Пятьдесят — предел по умолчанию у сервера.
const int searchPageSize = 50;

Map<String, String> _page(String query, int offset, {String? language}) => {
      "q": query,
      "limit": "$searchPageSize",
      if (offset > 0) "offset": "$offset",
      if (language != null && language.isNotEmpty) "language": language,
    };

/// Поиск по песнопениям. Не кэшируем: ручка тяжёлая, а повторная ценность
/// запроса низкая — та же причина, что записана в `lib/api/search.dart`.
Future<http.Response> fetchChants(String query, {int offset = 0, String? language}) {
  return v2Get(
    v2Uri("/chants", _page(query, offset, language: language)),
    retryAnonymously: false,
  );
}

/// Указатель зачинов. Тоже не кэшируем — это поиск.
Future<http.Response> fetchIncipits(String query, {int offset = 0, String? language}) {
  return v2Get(
    v2Uri("/incipits", _page(query, offset, language: language)),
    retryAnonymously: false,
  );
}

/// Карточка зачина. Вот её кэшируем: ключ — сам зачин, и содержимое за ним
/// меняется только с пересборкой корпуса.
Future<http.Response> fetchIncipit(String language, String incipit) {
  return cachedFetch(
    incipitCacheKey(language, incipit),
    () => v2Get(
      v2Uri("/incipits/${Uri.encodeComponent(language)}/${Uri.encodeComponent(incipit)}"),
      retryAnonymously: false,
    ),
    ttl: const Duration(days: 7),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded.containsKey("witnesses");
    },
  );
}

/// Ключ кэша карточки зачина.
///
/// Длина ключа входит в имя нарочно: `_sanitizeKey` в [cachedFetch] заменяет
/// всё не-буквенно-цифровое на подчёркивание, а зачин — это шесть слов через
/// пробелы. Без длины два разных зачина, различающиеся только знаками, легли бы
/// в один файл.
String incipitCacheKey(String language, String incipit) =>
    "incipit:$language:${incipit.length}:$incipit";
