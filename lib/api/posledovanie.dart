import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Последования молитвослова из раздела `/api/v2/posledovanie`.
///
/// Ручка в открытой зоне: ключ из девяти известных (`utrennie`, `na-son`,
/// `ko-prichashcheniyu` и проч.), язык `cu_gr`/`cu` и род молящегося `m`/`f`
/// меняют текст, поэтому всё трио входит в ключ кэша. Текст книжный и меняется
/// только с пересборкой корпуса — кладём на диск надолго, как карточки канонов
/// (`lib/api/singing.dart`).

Future<http.Response> fetchPosledovanie(
  String key, {
  String lang = "cu",
  String gender = "m",
}) {
  return cachedFetch(
    "posledovanie:$key:$lang:$gender",
    () => v2Get(v2Uri("/posledovanie", {
      "key": key,
      "lang": lang,
      "gender": gender,
    })),
    ttl: const Duration(days: 30),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      // Годен всякий разобранный ответ с рядами; 400 на плохой ключ сюда не
      // попадёт — не-200 `cachedFetch` в кэш не кладёт.
      return decoded is Map && decoded["rows"] is List;
    },
  );
}
