import 'package:http/http.dart' as http;

import 'client.dart';
import 'constants.dart';

/// Минимальная длина запроса. Столько же требует бекенд (`MIN_QUERY_LENGTH` в
/// `src/app/search/api.ts`), но короткий запрос отсекается ещё здесь: сервер на
/// него отвечает пустым 400 без объяснения, и внятное сообщение всё равно
/// пришлось бы придумывать на стороне приложения.
const int minSearchQueryLength = 3;

/// Поиск не кэшируется: повторная ценность у запроса низкая, а ручка тяжёлая
/// (полнотекстовый поиск по всему собранию) и ограничена по частоте.
Future<http.Response> searchString(String search) {
  // Через queryParameters, а не подстановкой в строку: иначе '&' или '#'
  // в запросе обрезали бы его на полуслове.
  final uri = Uri.parse('$apiBaseUrl/api/v1/search')
      .replace(queryParameters: {'query': search});
  return apiClient.get(uri).timeout(apiTimeout);
}
