import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'client.dart';
import 'constants.dart';

/// Трапеза на день.
///
/// Ручка не под v2: она заведена для строки на странице чтений и живёт своим
/// адресом, без ключа и без общего конверта ошибок. Ходим как в `/api/calc` —
/// через общий `apiClient`, чтобы не пропал `X-Typikon-App`.
///
/// Срок кэша делится, как у расчёта дня: прошедшая дата неизменна, будущая
/// живёт сутки. Это здесь не мелочь — за ответом стоит служба устава, которая
/// отвечает до восьми секунд, и лишний раз её тревожить незачем.
Future<http.Response> fetchTrapeza(String date) {
  final parsed = DateTime.tryParse(date);
  final isPast = parsed != null &&
      parsed.isBefore(DateTime.now().toUtc().copyWith(
            hour: 0,
            minute: 0,
            second: 0,
            millisecond: 0,
            microsecond: 0,
          ));

  return cachedFetch(
    "trapeza:$date",
    () => apiClient
        .get(Uri.parse('$apiBaseUrl/api/trapeza').replace(queryParameters: {"date": date}))
        .timeout(apiTimeout),
    ttl: isPast ? const Duration(days: 3650) : const Duration(hours: 24),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded.containsKey("kind");
    },
  );
}
