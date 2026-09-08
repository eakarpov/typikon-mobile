import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// Место, помеченное в тексте географическим именем.
///
/// Спрашивается и по идентификатору, и по псевдониму: в разметке текста стоит
/// то одно, то другое.
Future<http.Response> fetchPlace(String id) {
  return cachedFetch(
    'places:$id',
    () => v2Get(v2Uri('/places/$id')),
    ttl: const Duration(hours: 24),
  );
}
