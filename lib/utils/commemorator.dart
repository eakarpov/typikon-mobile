import 'package:flutter/foundation.dart';

import 'package:typikon/apiMapper/pomyannik.dart';
import 'package:typikon/apiMapper/session.dart';
import 'package:typikon/apiMapper/v2/errors.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/store.dart';

/// Открыт ли человеку приём записок.
///
/// Подтверждают это в личном кабинете на сайте, а отдельной ручки, чтобы о
/// подтверждении спросить, у сервера нет: единственный признак — как он
/// отвечает на сам раздел. `200` — открыт, `403` — нет.
///
/// **Спрашиваем редко.** Ответ меняется тогда, когда человека подтвердят, то
/// есть однажды и вручную; спрашивать при каждом запуске значит слать запрос
/// за ответом, который не менялся месяцами. Раз в сутки — с запасом.
///
/// **Отказ сети ничего не решает.** Прежний ответ остаётся: погасить раздел
/// из-за того, что метро проехало туннель, — значит отнять его у того, кому он
/// открыт.
@visibleForTesting
const Duration commemoratorFreshness = Duration(days: 1);

DateTime? _checkedAt;

@visibleForTesting
void resetCommemoratorCheck() => _checkedAt = null;

/// Подменяется тестом: сам запрос ходит в сеть и требует сессии.
@visibleForTesting
Future<bool> Function() askServer = _askServer;

@visibleForTesting
void resetCommemoratorSource() => askServer = _askServer;

Future<bool> _askServer() async {
  // Первая страница — самый дешёвый способ спросить: другого ответа на этот
  // вопрос сервер не даёт.
  await getReceivedNotes();
  return true;
}

/// Забыть, когда спрашивали.
///
/// Зовётся на выходе: под другой учётной записью прежний ответ не значит
/// ничего, а сам признак уходит вместе с `AuthState`.
void forgetCommemorator() => _checkedAt = null;

/// Спрашивает, если давно не спрашивали, и запоминает ответ в сторе.
Future<void> refreshCommemorator({bool force = false}) async {
  final store = appStore;
  if (store == null || !store.state.auth.isSignedIn) return;

  final checkedAt = _checkedAt;
  if (!force &&
      checkedAt != null &&
      DateTime.now().difference(checkedAt) < commemoratorFreshness) {
    return;
  }

  try {
    final open = await askServer();
    _checkedAt = DateTime.now();
    store.dispatch(CommemoratorCheckedAction(open));
  } on ApiUnauthorizedException {
    // Сервер ответил про этот самый раздел: приём не открыт. Это ответ, а не
    // поломка, и запоминается он так же, как «открыт».
    _checkedAt = DateTime.now();
    store.dispatch(CommemoratorCheckedAction(false));
  } on SessionExpiredException {
    // Вход погашен не здесь: этим ведает withSession.
  } catch (error) {
    debugPrint("Не спросилось про приём записок: $error");
  }
}
