import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Памяти со знаком службы.
///
/// **Страницы наружу, смещение внутрь.** Вторая версия API про страницы не
/// знает — она берёт `limit` и `offset`; экран же написан на страницах, и
/// переучивать его ради формы запроса незачем. Пересчёт живёт здесь, в одном
/// месте, а обратный — в `SignsList.fromJson`.
const int _signsPageSize = 100;

Future<http.Response> fetchSigns({int page = 1}) {
  final offset = (page - 1) * _signsPageSize;

  return cachedFetch(
    'signs:p$page',
    () => v2Get(v2Uri('/signs', {
      'limit': '$_signsPageSize',
      if (offset > 0) 'offset': '$offset',
    })),
    ttl: const Duration(hours: 24),
  );
}
