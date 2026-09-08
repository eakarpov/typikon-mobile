import 'package:flutter/foundation.dart';

import '../apiMapper/pomyannik.dart';
import '../store/pomyannik_cache.dart';
import 'pomyannik_labels.dart';

/// НАПОМИНАНИЕ О ПОМИНАЛЬНОМ ДНЕ.
///
/// Единственное, что приложение умеет, а сайт нет: сказать накануне, а не тогда,
/// когда человек зайдёт сам.
///
/// **Показывается по расписанию системы, а не по нашему.** Отложенных
/// уведомлений (`zonedSchedule`) здесь нет нарочно: каждое такое лежит в базе
/// системы до срабатывания, и год «Сороковой день: Николай» оказался бы там,
/// куда наша очистка при выходе не дотянется, — а на iOS пережил бы и
/// переустановку. Для раздела, вся посылка которого в том, что эти имена
/// принадлежат людям, не выбиравшим это приложение, так нельзя.
///
/// Взамен — пробуждение фоновой задачи, которая и без того ходит за новыми
/// текстами. Цена честная и названа в настройках: **напоминание может прийти
/// позже или не прийти вовсе в день, когда система не дала окна.** Обещать иное
/// про сороковой день хуже, чем не напоминать.
///
/// Отсюда и ворота ниже: окно даёт система, а показываем мы.

/// Раньше восьми утра и позже девяти вечера не показываем.
///
/// Вот и весь ответ на «как не разбудить в три ночи»: задача может проснуться
/// когда угодно, а уведомление уйдёт только внутри этого промежутка.
const int firstHour = 8;
const int lastHour = 21;

/// Зеркало старше двух недель к делу не годится: за это время хозяин мог
/// поправить или убрать имя в вебе, и напоминание о том, кого он убрал, хуже
/// молчания.
const Duration mirrorLifetime = Duration(days: 14);

@immutable
class ReminderVerdict {
  /// Что показать. `null` — не показывать ничего.
  final String? body;

  /// Куда вести по нажатию.
  final String? payload;

  /// Почему промолчали — для отладки и для теста, наружу не идёт.
  final String? silence;

  const ReminderVerdict._({this.body, this.payload, this.silence});

  const ReminderVerdict.silent(String why) : this._(silence: why);

  const ReminderVerdict.show(String body, String payload)
      : this._(body: body, payload: payload);

  bool get shows => body != null;
}

/// Показывать ли напоминание сейчас — и какое.
///
/// Чистое решение, без диска и без сети: ворота здесь такие, что ошибка в них
/// либо будит человека ночью, либо повторяет одно и то же четырежды за утро, и
/// проверять их надо отдельно от всего прочего.
ReminderVerdict pomyannikVerdict({
  required bool enabled,
  required PomyannikMirror? mirror,
  required String? lastNotifiedDate,
  required DateTime now,
  required bool withNames,
}) {
  if (!enabled) return const ReminderVerdict.silent("напоминания выключены");
  if (mirror == null) return const ReminderVerdict.silent("зеркала нет");

  if (now.difference(mirror.fetchedAt) > mirrorLifetime) {
    return const ReminderVerdict.silent("зеркало устарело");
  }

  if (now.hour < firstHour || now.hour >= lastHour) {
    return const ReminderVerdict.silent("не время суток");
  }

  final date = today(now);
  if (lastNotifiedDate == date) {
    return const ReminderVerdict.silent("сегодня уже говорили");
  }

  final events = mirror.on(date);
  if (events.isEmpty) return const ReminderVerdict.silent("сегодня нечего сказать");

  // Вчерашнее не доигрываем: «вчера был сороковой день» — это напоминание,
  // которое уже не сработало, и поданное поздно оно только обнадёживает зря.

  if (withNames) {
    final named = events.where((event) => event.title.isNotEmpty).toList();
    if (named.isNotEmpty) {
      return ReminderVerdict.show(
        named.length == 1 ? named.single.title : named.map((e) => e.title).join("; "),
        named.length == 1 && named.single.personId != null
            ? "pomyannik:${named.single.personId}"
            : "pomyannik:upcoming",
      );
    }
  }

  return ReminderVerdict.show(
    events.length == 1
        ? "Сегодня поминальный день"
        : "Сегодня поминальных дней: ${events.length}",
    "pomyannik:upcoming",
  );
}

/// Обновить зеркало.
///
/// Только из работающего приложения, а не из фоновой задачи, и вот почему: за
/// ответом стоит сессия, она живёт час, а продлить её молча можно лишь там, где
/// есть кому показать окно входа. В фоне попытка почти всегда упиралась бы в
/// отказ, а зеркало всё равно обновляется при следующем открытии приложения.
/// Устаревшее старше двух недель к делу не годится и молчит само.
Future<void> refreshPomyannikMirror(String? userId) async {
  if (userId == null || userId.isEmpty) return;

  try {
    final from = today();
    final upcoming = await getUpcoming(from: from, days: mirrorWindowDays);

    await writePomyannikMirror(
      PomyannikMirror(
        userId: userId,
        fetchedAt: DateTime.now(),
        from: upcoming.from.isEmpty ? from : upcoming.from,
        days: upcoming.days,
        events: upcoming.events,
      ),
      withNames: await namesInReminders(),
    );
  } catch (_) {
    // Сессия протухла, сети нет, сервер молчит — зеркало остаётся прежним. Оно
    // состарится само, и до тех пор напоминание вернее старого, чем никакого.
  }
}

/// Ширина окна зеркала. Шире, чем показывает экран: обновляется оно при
/// открытии приложения, а открывают его не каждый день.
const int mirrorWindowDays = 60;

/// Проверить и, если есть что сказать, сказать.
///
/// [show] отдаётся снаружи: сам показ уведомления живёт в `main.dart` рядом с
/// прочими, а сюда ходит только решение. [now] подменяется тестом.
Future<void> checkPomyannikAndNotify({
  required Future<void> Function(String body, String payload) show,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();

  final verdict = pomyannikVerdict(
    enabled: await remindersEnabled(),
    mirror: await readPomyannikMirror(),
    lastNotifiedDate: await lastPomyannikNotice(),
    now: at,
    withNames: await namesInReminders(),
  );

  if (!verdict.shows) return;

  await show(verdict.body!, verdict.payload!);
  await rememberPomyannikNotice(today(at));
}
