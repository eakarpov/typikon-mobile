import 'dart:convert';

import '../api/trapeza.dart';
import '../dto/trapeza.dart';

/// Разбор ответа о трапезе.
///
/// Ошибку наружу не бросаем вовсе: строка о посте — дополнение к чтениям, а не
/// они сами, и падать из-за неё или показывать «не удалось» над службой дня
/// значило бы поднять дополнение над главным. Не вышло — молчим.
Future<Trapeza> getTrapeza(String date) async {
  final response = await fetchTrapeza(date);
  if (response.statusCode != 200) return const Trapeza(kind: "unavailable");

  try {
    return Trapeza.fromJson(jsonDecode(response.body));
  } catch (_) {
    return const Trapeza(kind: "unavailable");
  }
}
