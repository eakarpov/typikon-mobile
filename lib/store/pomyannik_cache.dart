import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dto/pomyannik.dart';

/// ЗЕРКАЛО БЛИЖАЙШИХ ДНЕЙ — то, из чего складывается напоминание.
///
/// **Не в кэш-каталоге.** `cachedFetch` пишет в каталог, который чистит и
/// система под нехваткой места, и кнопка «сбросить кэш» в настройках. Оттого
/// напоминание тихо перестало бы приходить, а узнали бы об этом по пропущенному
/// сороковому дню. Здесь — каталог поддержки: его чистит только удаление
/// приложения.
///
/// **Имён в нём по умолчанию нет.** Это имена родни — людей, которые этого
/// приложения не выбирали, — и на диске им лежать незачем. Кто хочет видеть имя
/// в самом уведомлении, включает это сам; тогда имена и пишутся.
///
/// **Сам перечень лиц на диск не пишется вовсе.** Экраны держат его в памяти на
/// время маршрута и не дольше.
class PomyannikMirror {
  final String userId;
  final DateTime fetchedAt;

  /// С какого дня посчитано окно. Подвижные памяти и годовщины считаются от
  /// него: окно, посчитанное вчера, начинается вчера.
  final String from;

  final int days;
  final List<UpcomingEvent> events;

  const PomyannikMirror({
    required this.userId,
    required this.fetchedAt,
    required this.from,
    required this.days,
    this.events = const [],
  });

  List<UpcomingEvent> on(String date) =>
      events.where((event) => event.date == date).toList();

  Map<String, dynamic> toJson() => {
        "userId": userId,
        "fetchedAt": fetchedAt.toIso8601String(),
        "from": from,
        "days": days,
        "events": events.map((event) => event.toJson()).toList(),
      };

  static PomyannikMirror? fromJson(Map<String, dynamic> json) {
    final userId = json["userId"];
    final fetchedAt = DateTime.tryParse(json["fetchedAt"] ?? "");
    if (userId is! String || userId.isEmpty || fetchedAt == null) return null;

    return PomyannikMirror(
      userId: userId,
      fetchedAt: fetchedAt,
      from: json["from"] ?? "",
      days: json["days"] is int ? json["days"] : 0,
      events: json["events"] is List
          ? (json["events"] as List).map((e) => UpcomingEvent.fromJson(e)).toList()
          : const [],
    );
  }
}

/// Каталог зеркала. Подменяется тестами: `path_provider` — плагин платформы, и
/// в `flutter test` его нет.
@visibleForTesting
Future<Directory> Function() pomyannikDirectory = getApplicationSupportDirectory;

@visibleForTesting
void resetPomyannikDirectory() {
  pomyannikDirectory = getApplicationSupportDirectory;
}

Future<File> _file() async => File("${(await pomyannikDirectory()).path}/pomyannik_upcoming.json");

Future<PomyannikMirror?> readPomyannikMirror() async {
  try {
    final file = await _file();
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    return decoded is Map<String, dynamic> ? PomyannikMirror.fromJson(decoded) : null;
  } catch (_) {
    // Испорченное зеркало — то же самое, что его отсутствие: молчим.
    return null;
  }
}

/// Записать зеркало.
///
/// [withNames] решает, лягут ли на диск имена. По умолчанию не ложатся: событие
/// сохраняет дату и род, а заголовок с именем — нет.
Future<void> writePomyannikMirror(
  PomyannikMirror mirror, {
  required bool withNames,
}) async {
  try {
    final events = withNames
        ? mirror.events
        : mirror.events
            .map((event) => UpcomingEvent(
                  date: event.date,
                  kind: event.kind,
                  // Заголовок сервера несёт имя — «Сороковой день: Николай», —
                  // и без согласия хозяина ему на диске не место.
                  title: "",
                  personId: event.personId,
                  years: event.years,
                  custom: event.custom,
                ))
            .toList();

    final file = await _file();
    await file.writeAsString(jsonEncode(
      PomyannikMirror(
        userId: mirror.userId,
        fetchedAt: mirror.fetchedAt,
        from: mirror.from,
        days: mirror.days,
        events: events,
      ).toJson(),
    ));
  } catch (_) {
    // Не записалось — напоминания не будет. Ронять из-за этого приложение незачем.
  }
}

/// Выход из учётной записи стирает зеркало, а не прячет его.
Future<void> clearPomyannikCache() async {
  try {
    final file = await _file();
    if (await file.exists()) await file.delete();
  } catch (_) {}

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(lastNotifiedKey);
  } catch (_) {}
}

/// Своё ли это зеркало.
///
/// На одном устройстве входят и выходят разные люди — то же правило, что у
/// избранного: чужое зеркало удаляется, а не читается.
bool mirrorBelongsTo(PomyannikMirror? mirror, String? userId) =>
    mirror != null && userId != null && userId.isNotEmpty && mirror.userId == userId;

// --- Настройки напоминаний ----------------------------------------------------
//
// Обычными ключами `shared_preferences`, а не полем состояния Redux, и это не
// небрежность. Фоновая задача живёт в отдельном изоляте: хранилища состояния там
// нет вовсе, а разбирать ради двух булевых значений весь `APP_STATE` пришлось бы
// на каждое пробуждение. Заодно эти два значения не попадают в тот самый
// `APP_STATE`, куда имена не должны попасть ни при каких обстоятельствах.

const String remindersEnabledKey = "pomyannikRemindersEnabled";
const String namesInRemindersKey = "pomyannikNamesInReminders";
const String lastNotifiedKey = "pomyannikLastNotifiedDate";

/// По умолчанию выключено. Заводить уведомления об умерших родственниках
/// всякому, кто вошёл в учётную запись, нельзя.
Future<bool> remindersEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(remindersEnabledKey) ?? false;
}

/// По умолчанию имён в уведомлении нет: оно висит на экране блокировки. Тот же
/// выбор веб даёт хозяину у ленты календаря и по той же причине.
Future<bool> namesInReminders() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(namesInRemindersKey) ?? false;
}

Future<void> setRemindersEnabled(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(remindersEnabledKey, value);
}

/// Выключили имена — стираем и то, что уже легло на диск: настройка обязана
/// действовать назад, иначе имя останется в зеркале до следующего обновления.
Future<void> setNamesInReminders(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(namesInRemindersKey, value);
  if (!value) {
    final mirror = await readPomyannikMirror();
    if (mirror != null) await writePomyannikMirror(mirror, withNames: false);
  }
}

/// Когда в последний раз говорили. Фоновая задача просыпается несколько раз за
/// утро, и без этой отметки одно и то же напоминание пришло бы четырежды.
Future<String?> lastPomyannikNotice() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(lastNotifiedKey);
}

Future<void> rememberPomyannikNotice(String date) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(lastNotifiedKey, date);
}
