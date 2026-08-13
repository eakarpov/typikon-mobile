import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'constants.dart';

Future<http.Response> fetchCalendarDay(String dateTime) {
  // Past dates are effectively immutable, so cache them indefinitely; only
  // today/future dates get revalidated on the usual TTL.
  DateTime? parsed = DateTime.tryParse(dateTime);
  final isPast = parsed != null && parsed.isBefore(DateTime.now().toUtc().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0));
  return cachedFetch(
    'calc:$dateTime',
    () => http.post(
        Uri.parse('$apiBaseUrl/api/calc'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'date': dateTime,
        }),
    ).timeout(apiTimeout),
    ttl: isPast ? const Duration(days: 3650) : const Duration(hours: 24),
  );
}

Future<http.Response> fetchCalendarReadingForDate(int dateTime) {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/calendar/$dateTime'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
  ).timeout(apiTimeout);
}
