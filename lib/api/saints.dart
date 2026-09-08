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
      return decoded is Map && decoded.containsKey("memoryDates");
    },
  );
}
