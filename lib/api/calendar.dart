import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// День наряду: чтения, памяти и положение в подвижном круге.
///
/// **Прошедшие даты кладутся в кэш надолго.** День, который уже прошёл,
/// перемениться не может; перепроверять его — тратить сеть на заведомо тот же
/// ответ.
///
/// Тела текстов не просим: главная показывает, куда вести, а не сами тексты.
Future<http.Response> fetchCalendarDay(String dateTime) {
  final parsed = DateTime.tryParse(dateTime);
  final isPast =
      parsed != null &&
      parsed.isBefore(
        DateTime.now().toUtc().copyWith(
          hour: 0,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        ),
      );

  return cachedFetch(
    'calc:$dateTime',
    () => v2Get(v2Uri('/calendar/$dateTime')),
    ttl: isPast ? const Duration(days: 3650) : const Duration(hours: 24),
  );
}

/// Объединённые памяти Днеслова и каталога. Неполный ответ не кэшируется.
Future<http.Response> fetchDaySaints(String dateTime, {http.Client? client}) {
  // Каталог пополняется и для прошедших дат: прежний кэш на 10 лет
  // закреплял неполные ответы после отказа от прямой выдачи Днеслова.
  return cachedFetch(
    'saints-day:v2:$dateTime',
    () => v2Get(v2Uri('/calendar/$dateTime/saints'), client: client),
    ttl: const Duration(hours: 6),
    isCacheable: (body) {
      final decoded = jsonDecode(body);
      return decoded is Map &&
          decoded['saints'] is List &&
          decoded['partial'] != true;
    },
  );
}
