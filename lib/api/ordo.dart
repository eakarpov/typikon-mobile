import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Уставный день из раздела ordo: какие кафизмы читаются на дату.
///
/// Раздел молодой: сервер постарше ручку не знает, а у ключа доступа раздел
/// ordo может быть не открыт — тогда ответ будет отказом. Потребитель
/// (экран Псалтири) на любом таком исходе просто не помечает кафизмы
/// «сегодня»: см. `lib/apiMapper/ordo.dart`, бросать здесь нечего.

/// Дата в параметре `?date=` — ISO без времени, ноль дополнен.
String ordoDayDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, "0");
  return "${date.year.toString().padLeft(4, "0")}-${two(date.month)}-${two(date.day)}";
}

Future<http.Response> fetchOrdoDay(DateTime date) {
  final day = ordoDayDate(date);
  return cachedFetch(
    "ordo:day:$day",
    () => v2Get(v2Uri("/ordo/day", {"date": day})),
    ttl: const Duration(hours: 6),
    isCacheable: _isValidDay,
  );
}

/// Годен любой разобранный день.
///
/// У дня с кафизмами годность очевидна. Но кафизм может отсутствовать и у
/// честного ответа: старый сервер не знает поля, а отказ раздела у ключа не
/// всегда обозначен кодом. Поэтому кладём в кэш всякий объект-день, лишь бы
/// в нём не было кода ошибки; отказ (403, обрыв) сюда не доходит — не-200
/// ответы `cachedFetch` и так не кладёт.
bool _isValidDay(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return false;
  if (decoded.containsKey("kafizmy")) return true;
  return !decoded.containsKey("error");
}

/// JSON-проекция дневного .ordo-пакета. Тела уже привязаны сервером.
Future<http.Response> fetchOrdoServices(DateTime date) => cachedFetch(
  'ordo:services:${ordoDayDate(date)}',
  () => v2Get(
    v2Uri('/ordo/services', {
      'date': ordoDayDate(date),
      'lang': 'cu',
      'psalms': '1',
    }),
    retryAnonymously: false,
  ),
  isCacheable: (body) {
    final value = jsonDecode(body);
    return value is Map &&
        value['services'] is List &&
        !value.containsKey('error');
  },
);
