import 'package:http/http.dart' as http;

Future<http.Response> fetchCalendarDay(String dateTime, String calendarString) {
  return http.get(Uri.parse('http://dneslov.org/index.json?d=ю$dateTime&c=$calendarString'));
}

Future<http.Response> fetchCalendaries() {
  return http.get(Uri.parse('http://dneslov.org/calendaries.json?page=1&per=100&l=true'));
}

