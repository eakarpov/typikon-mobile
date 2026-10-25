import 'package:http/http.dart' as http;

import 'auth.dart';
import '../store/auth_token.dart';
import '../api/v2/error_body.dart';

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
Future<http.Response> withSession(
  Future<http.Response> Function() send, {
  Future<String?> Function()? readCookie,
  Future<bool> Function()? refresh,
  Future<void> Function()? forget,
}) async {
  final read = readCookie ?? getSessionCookie;
  Future<String?> cookie() async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }

  final originalCookie = await cookie();
  final response = await send();
  bool sessionRefused(http.Response value) =>
      value.statusCode == 401 &&
      (v2ErrorCode(value) == null || v2ErrorCode(value) == 'session_required');
  // Отказ ключа/раздела не имеет отношения к Google-аккаунту.
  if (!sessionRefused(response)) return response;
  if (originalCookie == null || originalCookie.isEmpty) {
    throw const SessionExpiredException();
  }
  final current = await cookie();
  final alreadyRefreshed = current != null && current != originalCookie;
  final refreshed =
      alreadyRefreshed || await (refresh ?? refreshSessionSilently)();
  if (!refreshed) {
    if (await cookie() == originalCookie) await (forget ?? forgetSession)();
    throw const SessionExpiredException();
  }
  final retriedCookie = await cookie();
  final retried = await send();
  if (sessionRefused(retried)) {
    if (await cookie() == retriedCookie) await (forget ?? forgetSession)();
    throw const SessionExpiredException();
  }
  return retried;
}
