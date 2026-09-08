import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Текст целиком.
Future<http.Response> fetchText(String id) {
  return cachedFetch(
    'text:$id',
    () => v2Get(v2Uri('/texts/$id')),
    ttl: const Duration(hours: 24),
  );
}

/// В какой день читается этот текст.
///
/// Обратный ход к дню: там спрашивают «что читается сегодня», здесь — «когда
/// читается вот это». Тела чтений не просим: экран показывает, куда вести, а не
/// сами тексты.
Future<http.Response> fetchDayByText(String id) {
  return cachedFetch(
    'text-day:$id',
    () => v2Get(v2Uri('/texts/$id/day')),
    ttl: const Duration(hours: 24),
  );
}

/// Что пополнилось: три последних правленных текста.
///
/// **Порядок просим явно.** Обычный у списка текстов — по месту в книге, и
/// одного `updatedSince` было бы мало: он отберёт нужные, а первыми отдаст те,
/// что раньше стоят в книге, — не те, что позже правились.
Future<http.Response> fetchLastTexts() {
  return cachedFetch(
    'texts:last',
    () => v2Get(v2Uri('/texts', {'sort': 'updated', 'limit': '3'})),
    ttl: const Duration(hours: 6),
  );
}
