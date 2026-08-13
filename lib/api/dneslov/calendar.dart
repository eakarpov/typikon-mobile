import 'package:http/http.dart' as http;

import '../constants.dart';

Future<http.Response> fetchCalendarDay(String dateTime, String calendarString) {
  return http.get(Uri.parse('$dneslovBaseUrl/index.json?d=ю$dateTime&c=$calendarString')).timeout(apiTimeout);
}

Future<http.Response> fetchCalendaries() {
  return http.get(Uri.parse('$dneslovBaseUrl/calendaries.json?page=1&per=100&l=true')).timeout(apiTimeout);
}
