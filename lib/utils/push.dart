import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../apiMapper/pomyannik.dart' as pomyannik;
import '../store/day_reading_notice.dart';

/// ТОЧНЫЕ НАПОМИНАНИЯ: пуш с сервера.
///
/// Приложение умеет напоминать о поминальном дне и само, фоновой задачей. Но
/// показывает оно напоминание тогда, когда система даст этой задаче окно, — то
/// есть когда придётся, а иной день и никогда. Пуш приходит в минуту.
///
/// **Пуш пустой, и это не мелочь.** Сервер присылает `data` без текста: он
/// лишь говорит, что сегодня у этого человека поминальный день. Что именно
/// сказать, решает то же правило `pomyannikVerdict`, по тому же зеркалу, что и
/// без сети. Иначе имена родни пришлось бы гнать через чужие серверы — а
/// приложение по той же причине отказалось и от отложенных уведомлений системы.
///
/// **Цена названа в настройках.** Остановленному силой приложению Android
/// пушей не отдаёт вовсе, пока его не откроют руками, и обойти это нельзя.
/// Поэтому выбор в настройках — не «лучше или хуже», а «всегда, но когда
/// придётся» против «в минуту, но при сети и не будучи остановленным».

/// **Двух напоминаний за день не будет.** Фоновая задача приложения продолжает
/// ходить и при выбранном сервере, но ворота «сегодня уже говорили» стоят внутри
/// самого правила: кто пришёл первым, тот и сказал. Оттого эти два пути не
/// спорят, а подстраховывают друг друга — пуш обыкновенно успевает раньше, а
/// не дошёл (нет сети, приложение остановлено) — скажет задача, пусть и позже.
///
/// Ключ доставки этого устройства. `null` — не спрашивали или не дали.
String? _token;

String? get pushToken => _token;

/// Подменяется тестом: `firebase_messaging` без живого устройства не работает.
@visibleForTesting
Future<String?> Function() readPushToken = _readPushTokenFromFirebase;

@visibleForTesting
void resetPushTokenSource() => readPushToken = _readPushTokenFromFirebase;

Future<String?> _readPushTokenFromFirebase() async {
  // Разрешение спрашиваем здесь, а не при запуске: до того как человек включил
  // пуши, спрашивать не о чем. Отказ — обычный ответ, а не поломка.
  final settings = await FirebaseMessaging.instance.requestPermission();
  if (settings.authorizationStatus == AuthorizationStatus.denied) return null;

  return FirebaseMessaging.instance.getToken();
}

/// Поднять Firebase. Зовётся один раз при запуске.
///
/// Молча переживает неудачу: без Firebase приложение остаётся приложением, а
/// напоминания — за фоновой задачей. Падать на запуске из-за службы уведомлений
/// было бы несоразмерно.
Future<bool> initPush() async {
  try {
    await Firebase.initializeApp();
    return true;
  } catch (error) {
    debugPrint("Firebase не поднялся: $error");
    return false;
  }
}

/// Включить пуши: взять ключ доставки и отдать его серверу.
///
/// Возвращает, вышло ли. Не вышло — приложению остаётся его собственная фоновая
/// задача, и настройка честно вернётся к «шлёт приложение».
Future<bool> enablePush() async {
  final token = await readPushToken();
  if (token == null || token.isEmpty) return false;

  // Пояс берём у устройства и отдаём вместе с ключом: сервер считает утро по
  // месту телефона. `DateTime.now().timeZoneName` даёт сокращение вроде «MSK»,
  // а серверу нужен IANA — его знает только сама система.
  final zone = await deviceTimeZone();
  // Час чтений отдаём вместе с ключом: сервер шлёт пуш в него, а не в общий
  // для всех восьмой. Не выбран — сервер о чтениях этому устройству не пишет.
  final hour = await dayReadingHour();
  final ok = await pomyannik.registerDevice(token, zone, readingHour: hour);
  if (ok) _token = token;

  return ok;
}

/// Выключить пуши: отвязать устройство.
Future<void> disablePush() async {
  final token = _token ?? await readPushToken();
  if (token == null || token.isEmpty) return;

  await pomyannik.forgetDevice(token);
  _token = null;
}

/// Часовой пояс устройства в записи IANA.
///
/// `DateTime.now().timeZoneName` для этого не годится, хотя и просится: он
/// отдаёт сокращение («MSK», «+07»), а по сокращению пояс однозначно не
/// восстановить — EST это и Нью-Йорк, и Канкун, с разными правилами перехода.
/// Сервер такую строку и не примет: он проверяет пояс на приёме.
///
/// Имя пояса знает только система, и спрашивается оно у неё.
Future<String> deviceTimeZone() async {
  try {
    final zone = await FlutterTimezone.getLocalTimezone();
    final name = zone.identifier;
    if (name.isNotEmpty) return name;
  } catch (error) {
    debugPrint("Пояс устройства не спросился: $error");
  }

  // Спросить не вышло. Молчать нельзя — без пояса сервер устройство не примет
  // вовсе, — а Москва хотя бы правдоподобна: приложение русское.
  return "Europe/Moscow";
}

/// Перепривязать устройство при запуске.
///
/// Ключ доставки не вечен: он меняется при переустановке, при очистке данных и
/// сам по себе — Firebase его иногда обновляет. Записанный на сервере старый
/// ключ мёртв, и пуши перестали бы приходить молча, без единой ошибки на
/// экране. Поэтому при каждом запуске с выбранным сервером ключ отдаётся
/// заново, а заодно и часовой пояс — человек мог переехать.
Future<void> refreshPushRegistration({required bool wanted}) async {
  if (!wanted) return;

  try {
    await enablePush();
  } catch (error) {
    debugPrint("Перепривязка устройства не вышла: $error");
  }
}

/// Слушать смену ключа доставки.
///
/// Firebase меняет его и посреди работы приложения; без этого до следующего
/// запуска пуши уходили бы в пустоту.
void watchPushToken({required bool Function() wanted}) {
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    if (!wanted()) return;
    _token = token;
    await pomyannik.registerDevice(token, await deviceTimeZone(),
        readingHour: await dayReadingHour());
  });
}
