import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'client.dart';
import 'constants.dart';

/// Список памятей со знаком. Ответ постраничный, размер страницы задаёт
/// сервер, поэтому кэшируем каждую страницу отдельным ключом.
Future<http.Response> fetchSigns({int page = 1}) {
  return cachedFetch(
    'signs:p$page',
    () => apiClient
        .get(Uri.parse('$apiBaseUrl/api/v1/signs?page=$page'))
        .timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}
