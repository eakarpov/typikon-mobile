import 'package:http/http.dart' as http;

import 'auth.dart';

/// Защищённый запрос вернул 401, и продлить сессию молча не удалось —
/// пользователю нужно войти заново. Отдельный тип, чтобы страницы могли
/// отличить "сессия истекла" от "не загрузилось" и от "пусто".
class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => "SessionExpiredException";
}

/// Отправляет запрос, требующий сессии, и один раз переигрывает его, если
/// сессия успела истечь.
///
/// Сессия на бекенде живёт час, поэтому 401 здесь — не ошибка, а нормальный
/// ход событий для приложения, которое остаётся открытым дольше. Порядок:
/// запрос → 401 → тихое продление → тот же запрос ещё раз. Если продлить не
/// вышло, локальный вход гасится (`forgetSession`) и наверх летит
/// [SessionExpiredException].
///
/// [send] вызывается заново целиком, а не переиспользует готовый запрос:
/// заголовок с cookie собирается внутри `api/*`, и повторный вызов подхватит
/// уже новую сессию.
Future<http.Response> withSession(Future<http.Response> Function() send) async {
  final response = await send();
  if (response.statusCode != 401) return response;

  final refreshed = await refreshSessionSilently();
  if (!refreshed) {
    await forgetSession();
    throw const SessionExpiredException();
  }

  final retried = await send();
  if (retried.statusCode == 401) {
    await forgetSession();
    throw const SessionExpiredException();
  }
  return retried;
}
