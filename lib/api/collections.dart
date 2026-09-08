import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Седмицы года по кругам.
///
/// Первая версия API держала три отдельные ручки, вторая — одну с кругом в
/// запросе. Кэш остаётся раздельным: круги листают порознь, и общий ключ гонял
/// бы по сети то, что уже лежит на диске.
///
/// **Круг «вне Триоди» пришлось сперва завести на сервере.** Он там был
/// пропущен, и запрос на него отвечал не отказом, а союзом двух других кругов:
/// двадцать седмиц вместо пятидесяти трёх, и по виду ответа не отличить.
Future<http.Response> _weeks(String cycle) {
  return cachedFetch(
    'collections:$cycle',
    () => v2Get(v2Uri('/weeks', {'cycle': cycle, 'limit': '100'})),
    ttl: const Duration(days: 7),
  );
}

Future<http.Response> fetchPenticostarion() => _weeks('penticostarion');

Future<http.Response> fetchTriodion() => _weeks('triodion');

Future<http.Response> fetchOutTriodion() => _weeks('out-triodion');

/// Одна седмица со своими днями.
///
/// Кэш длинный: состав седмицы меняется реже всего в корпусе.
Future<http.Response> fetchWeek(String alias) {
  return cachedFetch(
    'weeks:$alias',
    () => v2Get(v2Uri('/weeks/$alias')),
    ttl: const Duration(days: 7),
  );
}
