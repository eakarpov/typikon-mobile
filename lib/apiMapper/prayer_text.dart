import 'dart:convert';

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
}) async {
  final response = await withSession(
    () => api.fetchPrayerText(forKind: forKind, gender: gender),
  );
  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      return PrayerText.fromJson(Map<String, dynamic>.from(decoded)).prayers;
    }
  }
  throwV2Error(response, "Не удалось загрузить молитвы с именами");
}
