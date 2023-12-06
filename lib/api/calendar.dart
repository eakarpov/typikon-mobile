import 'dart:convert';

import 'package:http/http.dart' as http;

Future<http.Response> fetchCalendarDay(String dateTime) {
  return http.post(
      Uri.parse('https://typikon.su/api/calc'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'date': dateTime,
      }),
  );
}

Future<http.Response> fetchCalendarReadingForDate(int dateTime) {
  return http.get(
    Uri.parse('https://typikon.su/api/v1/calendar/$dateTime'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
  );
}
