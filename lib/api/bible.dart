import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Запросы к Библии второй версии API.
///
/// Всё здесь читающее и практически неизменное, поэтому кэш держим долго и
/// полагаемся на stale-while-revalidate: устаревшая запись отдаётся мгновенно, а
/// свежая подтягивается в фоне — читатель подмены не замечает.

/// Набор изданий в каноническом виде: без пустых, без повторов, по алфавиту.
///
/// Сортировка не косметика. Тело ответа зависит от набора И от порядка (сервер
/// строит колонки в том порядке, в каком их перечислили), а имя файла в кэше — от
/// ключа. Не приведи мы порядок к одному виду, «ЦС, греч.» и «греч., ЦС» легли бы
/// в один файл разными телами, и вторая пара показала бы колонки от первой.
///
/// Плата — колонки идут в алфавитном порядке кода, а не в том, в каком издания
/// перечисляет сервер. Она невелика: порядок изданий известен из `/bible/editions`,
/// и переставить колонки можно уже на своей стороне, ничего не перезапрашивая.
List<String> canonicalEditionCodes(Iterable<String> codes) {
  final unique = codes
      .map((code) => code.trim())
      .where((code) => code.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return unique;
}

/// Ключ кэша главы.
///
/// Число кодов входит в ключ нарочно. `_sanitizeKey` в [cachedFetch] заменяет всё
/// не-буквенно-цифровое на подчёркивание, поэтому `cs-eliz,ro-1688` и
/// одиночный код `cs-eliz-ro-1688` дали бы одно имя файла. Сегодня таких кодов
/// нет, но полагаться на это молча нельзя: длина набора их разводит.
String bibleChapterCacheKey(String canonId, int chapter, List<String> editions) {
  final codes = canonicalEditionCodes(editions);
  return "bible:chapter:$canonId:$chapter:${codes.length}:${codes.join(",")}";
}

/// Годным считаем только то, что разбирается и содержит ожидаемое поле.
///
/// Кода 200 недостаточно: именно так — двумястами с пустым телом — отвечает v1 на
/// исчезнувший текст, и такой ответ, положенный на диск, живёт весь срок кэша.
bool Function(String body) _bodyHas(String key) {
  return (String body) {
    final decoded = jsonDecode(body);
    return decoded is Map && decoded.containsKey(key);
  };
}

/// Оглавление: книги канона и приложения.
///
/// Тридцать дней — потому что канон закрыт по устройству данных: идентификаторы
/// книг это адреса, по ним резолвятся зачала, и меняться они не должны.
Future<http.Response> fetchBibleBooks() {
  return cachedFetch(
    "bible:books",
    () => v2Get(v2Uri("/bible/books")),
    ttl: const Duration(days: 30),
    isCacheable: _bodyHas("items"),
  );
}

/// Издания. Неделя: издание появляется несколько раз в год.
Future<http.Response> fetchBibleEditions() {
  return cachedFetch(
    "bible:editions",
    () => v2Get(v2Uri("/bible/editions")),
    ttl: const Duration(days: 7),
    isCacheable: _bodyHas("items"),
  );
}

/// Глава в выбранных изданиях.
///
/// Пустой список изданий уходит без параметра: сервер понимает это как «все
/// публичные». Это же и запасной ход, если список изданий не загрузился, —
/// худшее, что получит читатель, глава во всех изданиях вместо выбранного, а не
/// пустой экран.
Future<http.Response> fetchBibleChapter(
  String canonId,
  int chapter, {
  List<String> editions = const [],
}) {
  final codes = canonicalEditionCodes(editions);
  final query = codes.isEmpty ? null : {"editions": codes.join(",")};

  return cachedFetch(
    bibleChapterCacheKey(canonId, chapter, codes),
    () => v2Get(v2Uri("/bible/$canonId/$chapter", query)),
    ttl: const Duration(days: 30),
    isCacheable: _bodyHas("verses"),
  );
}
