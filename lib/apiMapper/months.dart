import 'dart:convert';

import "package:typikon/dto/month.dart";
import "package:typikon/api/months.dart";

Future<MonthList> getMonths() async {
  final response = await fetchMonths();

  if (response.statusCode == 200) {
    return MonthList.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получены результаты');
  }
}

Future<MonthWithDays> getMonth(String id) async {
  final response = await fetchMonth(id);

  if (response.statusCode == 200) {
    return MonthWithDays.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получены результаты');
  }
}