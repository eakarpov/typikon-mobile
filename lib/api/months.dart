import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Месяцы неподвижного круга.
///
/// **Месяц спрашивается по псевдониму, а не по идентификатору.** Первая версия
/// API брала и то и другое, вторая — псевдоним («january»), и он же стоит в
/// адресах страниц сайта. Экран списка отдаёт его дальше сам.
///
/// **Карточка месяца во второй версии много легче.** Первая отдавала дни СО
/// ВСЕМИ их текстами — тридцать одна служба целиком ради списка из тридцати
/// одного имени; вторая отдаёт имя, псевдоним и число. Экрану месяца больше и
/// не нужно: он рисует имя и ведёт по нажатию.
Future<http.Response> fetchMonths() {
  return cachedFetch(
    'months',
    () => v2Get(v2Uri('/months', {'limit': '50'})),
    ttl: const Duration(days: 7),
  );
}

Future<http.Response> fetchMonth(String alias) {
  return cachedFetch(
    'months:$alias',
    () => v2Get(v2Uri('/months/$alias')),
    ttl: const Duration(days: 7),
  );
}
