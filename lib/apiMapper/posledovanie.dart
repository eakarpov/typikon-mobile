import 'dart:convert';

import '../api/posledovanie.dart';
import '../dto/posledovanie.dart';
import 'v2/errors.dart';

/// Разбор последования молитвослова.
///
/// Отказы разбирает общий `throwV2Error`: ручка открытая, и её 400 («нет такого
/// ключа») — честный ответ сервера, а не поломка приложения.

Future<Posledovanie> getPosledovanie(
  String key, {
  String lang = "cu",
  String gender = "m",
}) async {
  final response = await fetchPosledovanie(key, lang: lang, gender: gender);
  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      return Posledovanie.fromJson(Map<String, dynamic>.from(decoded));
    }
  }
  throwV2Error(response, "Не удалось открыть последование");
}
