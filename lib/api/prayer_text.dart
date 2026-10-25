import 'package:http/http.dart' as http;

import 'v2/request.dart';

/// Молитвы с именами из помянника (`/api/v2/prayer-text`).
///
/// **Личное не кэшируется в общем http-кэше.** Запрос идёт через [v2Send], а не
/// `cachedFetch` (см. тот же принцип у помянника, `lib/api/pomyannik.dart`):
/// имена родни на диск в общий кэш-каталог не кладутся. Снимок для офлайна —
/// свой, в `SharedPreferences`, и живёт он в `store/psalter_prayers.dart`.
///
/// Имена клиент не шлёт: сервер сам берёт living/departed из своего помянника
/// и подставляет их в тексты. Поэтому ручка и личная — без входа `401`.

/// Единственный стиль, который использует приложение: краткие молитвы
/// молитвослова об усопших и о живых.
const String prayerStyleMolitvoslovShort = "molitvoslov-short";

Future<http.Response> fetchPrayerText({
  required String forKind,
  required String gender,
  String? style,
  http.Client? client,
}) {
  return v2Send(
    "GET",
    v2Uri("/prayer-text", {
      "for": forKind,
      "style": style ?? prayerStyleMolitvoslovShort,
      "lang": "cu",
      "gender": gender,
    }),
    client: client,
  );
}
