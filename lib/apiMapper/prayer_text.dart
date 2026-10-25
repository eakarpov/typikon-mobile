import 'dart:convert';
import 'package:http/http.dart' as http;

import '../api/prayer_text.dart' as api;
import '../dto/prayer_text.dart';
import 'session.dart';
import 'v2/errors.dart';

/// Разбор молитв с именами из помянника.
///
/// Всякий личный вызов идёт через [withSession]: протухшая сессия молча
/// продлевается и запрос повторяется; не вышло — летит
/// [SessionExpiredException], и страница просит войти. Прочие отказы разбирает
/// общий `throwV2Error`.

/// Молитвы «для кого» — с именами, которые сервер возьмёт из своего помянника.
Future<List<NamedPrayer>> getNamedPrayers({
  required String forKind,
  required String gender,
  String? style,
  Future<http.Response> Function()? request,
}) async {
  final response = await withSession(
    request ??
        () =>
            api.fetchPrayerText(forKind: forKind, gender: gender, style: style),
  );
  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      if (decoded['for'] != null && decoded['for'] != forKind) {
        throw const FormatException(
          'Сервер вернул молитву для другого вида поминовения',
        );
      }
      final prayers = PrayerText.fromJson(
        Map<String, dynamic>.from(decoded),
      ).prayers.where((p) => p.text.trim().isNotEmpty).toList();
      if (prayers.isEmpty) {
        throw const FormatException('Сервер не вернул тексты молитв');
      }
      return prayers;
    }
  }
  throwV2Error(response, "Не удалось загрузить молитвы с именами");
}
