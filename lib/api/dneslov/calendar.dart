import 'package:http/http.dart' as http;

import '../cached_fetch.dart';
import '../constants.dart';

Future<http.Response> fetchCalendarDay(String dateTime, String calendarString) {
  return cachedFetch(
    'dneslov-calendar:$dateTime:$calendarString',
    () => http.get(Uri.parse('$dneslovBaseUrl/index.json?d=ю$dateTime&c=$calendarString')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}

Future<http.Response> fetchCalendaries() {
  return cachedFetch(
    'dneslov-calendaries',
    () => http.get(Uri.parse('$dneslovBaseUrl/calendaries.json?page=1&per=100&l=true')).timeout(apiTimeout),
    ttl: const Duration(days: 7),
  );
}
