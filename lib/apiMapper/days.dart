import 'dart:convert';

import '../dto/day.dart';
import "../api/days.dart";

Future<DayTexts> getDay(String id) async {
  final response = await fetchDay(id);

  if (response.statusCode == 200) {
    return DayTexts.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Календарь пока недоступен');
  }
}