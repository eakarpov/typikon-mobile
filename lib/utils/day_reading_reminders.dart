import 'package:flutter/foundation.dart';

import '../apiMapper/calendar.dart';
import '../dto/calendar.dart';
import '../store/day_reading_notice.dart';

/// УВЕДОМЛЕНИЕ О ЧТЕНИЯХ ДНЯ.
///
/// **Час выбирает человек, а не мы.** Восемь утра не всеобщее время: кто-то
/// читает до работы, кто-то накануне вечером, чтобы успеть на вечерню. Поэтому
/// правило ниже спрашивает час, а не «включено ли».
///
/// **Окно, а не мгновение.** Фоновая задача просыпается, когда система даст ей
/// окно, и попасть ровно в назначенную минуту она не может. Час назначенный и
/// следующий за ним — то, в чём уведомление ещё уместно; позже оно приходит не
/// вовремя, а невпопад. Толчок с сервера приходит в минуту и в это окно
/// попадает всегда.
///
/// **Дважды за день не говорим.** Ворота те же, что у помянника, и по той же
/// причине: задача просыпается несколько раз, а сказать надо один.

/// Сколько часов после назначенного уведомление ещё уместно.
const int readingWindowHours = 2;

@immutable
class ReadingNotice {
  /// Что показать. `null` — не показывать ничего.
  final String? body;

  /// Куда вести по нажатию.
  final String? payload;

  /// Почему промолчали — для отладки и для теста, наружу не идёт.
  final String? silence;

  const ReadingNotice._({this.body, this.payload, this.silence});

  const ReadingNotice.silent(String why) : this._(silence: why);

  const ReadingNotice.show(String body, String payload)
      : this._(body: body, payload: payload);

  bool get shows => body != null;
}

/// Говорить ли сейчас о чтениях дня — и что.
///
/// Чистое решение, без диска и без сети: ошибка в этих воротах либо будит
/// человека ночью, либо повторяет одно и то же несколько раз за утро.
ReadingNotice readingVerdict({
  required int? hour,
  required CalendarDay? day,
  required String? lastNotifiedDate,
  required DateTime now,
}) {
  if (hour == null) return const ReadingNotice.silent("час не выбран");

  final date = _today(now);
  if (lastNotifiedDate == date) {
    return const ReadingNotice.silent("сегодня уже говорили");
  }

  if (now.hour < hour || now.hour >= hour + readingWindowHours) {
    return const ReadingNotice.silent("не время");
  }

  // Дня нет — значит не достали: сети не было или служба устава молчит.
  // Промолчать здесь правильнее, чем сказать «чтения готовы» и открыть пустоту.
  if (day == null) return const ReadingNotice.silent("дня нет");

  final memory = day.memories.defaultMemory?.name.trim() ?? "";
  final name = day.name.trim();
  // Память дня говорит больше, чем «Вторник пятнадцатой седмицы», и потому идёт
  // первой; но у рядового дня памяти может не быть вовсе, и тогда имя дня —
  // единственное, что есть.
  final title = memory.isNotEmpty ? memory : name;
  if (title.isEmpty) return const ReadingNotice.silent("нечего сказать");

  final places = day.readings.where((r) => r.items.isNotEmpty).length;
  final body = places > 0 ? "$title · чтений: $places" : title;

  return ReadingNotice.show(body, "reading:${day.alias ?? date}");
}

String _today(DateTime at) =>
    "${at.year.toString().padLeft(4, '0')}-"
    "${at.month.toString().padLeft(2, '0')}-"
    "${at.day.toString().padLeft(2, '0')}";

/// Сказать о чтениях дня, если пора.
///
/// Показ отделён от решения: решение чистое и проверяется тестами, а здесь —
/// диск, сеть и уведомление. Тот же порядок, что у напоминаний помянника.
///
/// День берётся за сегодня по местному времени. Сети может не быть — тогда
/// ответ придёт из кэша, а не придёт вовсе — промолчим: обещать чтения и
/// открыть пустой экран хуже молчания.
Future<void> checkReadingAndNotify({
  required Future<void> Function(String body, String payload) show,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final hour = await dayReadingHour();
  if (hour == null) return;

  // Спрашиваем день ТОЛЬКО когда час подошёл: иначе фоновая задача ходила бы в
  // сеть по нескольку раз в сутки ради ответа, который никому не покажут.
  final date = _today(at);
  if (await lastReadingNotice() == date) return;
  if (at.hour < hour || at.hour >= hour + readingWindowHours) return;

  CalendarDay? day;
  try {
    day = await getCalendarDay(date);
  } catch (_) {
    day = null;
  }

  final verdict = readingVerdict(
    hour: hour, day: day, lastNotifiedDate: null, now: at);
  if (!verdict.shows) return;

  await show(verdict.body!, verdict.payload!);
  await rememberReadingNotice(date);
}
