import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';

Future<http.Response> fetchCalendarDay(String dateTime) {
  return http.post(
      Uri.parse('$apiBaseUrl/api/calc'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'date': dateTime,
      }),
  ).timeout(apiTimeout);
}

Future<http.Response> fetchCalendarReadingForDate(int dateTime) {
  return http.get(
    Uri.parse('$apiBaseUrl/api/v1/calendar/$dateTime'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
  ).timeout(apiTimeout);
}
