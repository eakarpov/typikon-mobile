import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Книги библиотеки.
///
/// Сорок девять и во второй версии API, и в первой — сверено до перехода:
/// `/v2/books` отбирает по `public`, а `/v1/library` не отбирал ничего, и книги
/// могли пропасть не от ошибки, а потому что им там и не место.
Future<http.Response> fetchLibrary() {
  return cachedFetch(
    'library',
    () => v2Get(v2Uri('/books', {'limit': '200'})),
    ttl: const Duration(hours: 24),
  );
}

Future<http.Response> fetchBook(String id) {
  return cachedFetch(
    'library:$id',
    () => v2Get(v2Uri('/books/$id')),
    ttl: const Duration(hours: 24),
  );
}

/// Столько же, сколько берёт сервер за раз.
const int _maxBatch = 200;

/// Тексты поимённо: избранное.
///
/// **Не отдельной ручкой, а отбором у списка текстов.** Первая версия API имела
/// для этого `POST /texts/batch` со списком в теле; вторая берёт `ids` в
/// запросе — тот же отбор, та же выдача, тот же разбор.
///
/// **Спрашиваем частями.** Двести за раз — потолок сервера, и он же предел
/// разумной длины адреса. У избранного пятисот имён не бывает, но упереться в
/// молчаливо обрезанную выдачу хуже, чем сделать два запроса.
Future<http.Response> batchTexts(List<String> ids) async {
  if (ids.isEmpty) {
    // Пустой список — не повод спрашивать сервер: он ответил бы отказом, а
    // ответ «ничего не нашлось» мы знаем и без него.
    return http.Response(jsonEncode({'items': [], 'total': 0}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }

  if (ids.length <= _maxBatch) {
    return v2Get(v2Uri('/texts', {'ids': ids.join(','), 'limit': '$_maxBatch'}));
  }

  final gathered = <dynamic>[];
  for (var from = 0; from < ids.length; from += _maxBatch) {
    final part = ids.sublist(from, from + _maxBatch > ids.length ? ids.length : from + _maxBatch);
    final response = await v2Get(v2Uri('/texts', {'ids': part.join(','), 'limit': '$_maxBatch'}));
    if (response.statusCode != 200) return response;

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    gathered.addAll(decoded["items"] as List? ?? const []);
  }

  return http.Response(
    jsonEncode({'items': gathered, 'total': gathered.length}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
