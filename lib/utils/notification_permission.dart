import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Разрешение показывать уведомления — спрашивается тогда, когда есть о чём.
///
/// Прежде его просили в `initState` самого приложения, то есть системным окном
/// на первом же запуске, поверх пустого экрана и без единого слова о том, зачем.
/// На такой вопрос отвечают «нет» чаще, чем на любой другой, а на Android
/// второй отказ окончателен: окно больше не показывается вовсе, и включить
/// напоминания потом нельзя ничем, кроме настроек системы.
///
/// Поэтому спрашиваем в тот миг, когда человек сам включает то, что будет
/// напоминать. Об обновлении при этом по-прежнему скажет окно внутри
/// приложения — оно разрешения не требует и есть у всех.
///
/// То же правило уже соблюдает `utils/push.dart`: там разрешение спрашивается
/// при включении пушей, а не при запуске.
///
/// Возвращает, дали ли. Плагин — одиночка, поэтому это тот же самый экземпляр,
/// что поднят в `main()`.
Future<bool> ensureNotificationPermission() async {
  final plugin = FlutterLocalNotificationsPlugin();

  try {
    if (Platform.isAndroid) {
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Уже дано — второй раз не спрашиваем: на Android вопрос повторно и не
      // покажется, а вот отказ бы запомнился.
      if (await android?.areNotificationsEnabled() ?? false) return true;
      return await android?.requestNotificationsPermission() ?? false;
    }

    if (Platform.isIOS) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
  } catch (error) {
    debugPrint("Разрешение на уведомления не спросилось: $error");
  }

  return false;
}
