import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Досье святого: запись каталога и всё, что к ней привязано.
///
/// Адрес принимает и слуг, и номер святцев — обе формы живут в разметке
/// корпуса: ссылки внутри текстов стоят номерами, а в святцах и указателе имён
/// — слугами. Сузить адрес до одного вида значит сломать половину переходов,
/// поэтому он уходит на сервер как есть.
///
/// Срок кэша — сутки, и это не осторожность, а необходимость: гражданские даты
/// в `memoryDates` посчитаны сервером на день запроса (ближайшее выпадение, а
/// не то же число этого года). Полежав неделю, ответ начнёт называть память
/// прошедшим числом.
Future<http.Response> fetchSaintDossier(String address) {
  return cachedFetch(
    // Длина в ключе — потому что `_sanitizeKey` схлопывает разделители, и слуг
    // с дефисами способен совпасть с чужим ключом после чистки.
    "saint:${address.length}:$address",
    () => v2Get(v2Uri("/saints/dossier/${Uri.encodeComponent(address)}")),
    ttl: const Duration(hours: 24),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map &&
          decoded.containsKey("memoryDates") &&
          (!decoded.containsKey("works") || decoded["works"] != null);
    },
  );
}

/// Житие из каталога памятей — притягивает его наш серверный прокси.
///
/// Адрес принимает и слуг, и номер святцев: резолвит их сам сервер, и ходить
/// за номером через досье, как раньше, больше не нужно. Срок кэша — месяц:
/// житие пишется раз и надолго, а связь с каталогом не зависит от дня запроса,
/// как у досье.
Future<http.Response> fetchSaintLife(String address) {
  return cachedFetch(
    "saint-life:${address.length}:$address",
    () => v2Get(v2Uri("/saints/dossier/${Uri.encodeComponent(address)}/life")),
    ttl: const Duration(days: 30),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded.containsKey("memoes");
    },
  );
}

Future<http.Response> fetchSaintChant(String id) => cachedFetch(
  'saint-chant:$id',
  () => v2Get(v2Uri('/chants/${Uri.encodeComponent(id)}')),
  isCacheable: (body) =>
      jsonDecode(body) is Map && jsonDecode(body)['text'] is String,
);

Future<http.Response> fetchSaintService(String id, String? language) =>
    cachedFetch(
      'saint-service:$id:$language',
      () => v2Get(
        v2Uri('/saints/service/${Uri.encodeComponent(id)}', {
          'lang': ?language,
        }),
      ),
      isCacheable: (body) =>
          jsonDecode(body) is Map && jsonDecode(body)['rows'] is List,
    );
