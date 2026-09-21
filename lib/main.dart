import "dart:ui";
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import "package:background_fetch/background_fetch.dart";
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import "routes.dart";
import "pages/not_found_page.dart";
import "api/constants.dart";
import "utils/app_version.dart";
import "utils/day_reading_reminders.dart";
import "utils/push.dart";
import "utils/crash_reporter.dart";

import "package:typikon/apiMapper/version.dart";
import "package:typikon/apiMapper/reading.dart";
import 'package:typikon/utils/route_observer.dart';

import "package:typikon/store/index.dart";
import "package:typikon/store/store.dart";
import "package:typikon/store/pomyannik_cache.dart";
import "package:typikon/utils/pomyannik_reminders.dart";

int id = 0;

const String navigationActionId = 'id_3';

const String wantToGetUpdate = "wantToGetUpdate";

const String newTextPayloadPrefix = "newText:";
const String pomyannikPayloadPrefix = "pomyannik:";
const String _lastSeenTextIdKey = "last_seen_text_id";

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Нужен, чтобы открыть текст по тапу на уведомление о новом тексте —
// колбэк стрима вне дерева виджетов, без своего BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


/// Streams are created so that app can respond to notification-related events
/// since the plugin is initialised in the `main` function
final StreamController<ReceivedNotification> didReceiveLocalNotificationStream =
StreamController<ReceivedNotification>.broadcast();

final StreamController<String?> selectNotificationStream =
StreamController<String?>.broadcast();

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ставим до всего остального, чтобы падения самой инициализации тоже доехали.
  installCrashReporting();
  // initialise the plugin of flutter local notifications

  // app_icon needs to be a added as a drawable
  // resource to the Android head project.
  var android = new AndroidInitializationSettings('@mipmap/ic_launcher');
  var IOS = new DarwinInitializationSettings();

  // initialise settings for both Android and iOS device.
  var settings = new InitializationSettings(
    android: android,
    iOS: IOS,
  );
  // Ни один из шагов ниже не стоит пустого экрана: сорвался — приложение
  // открывается без него, а сбой уезжает в отчёт о падениях.
  try {
    await flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
        switch (notificationResponse.notificationResponseType) {
          case NotificationResponseType.selectedNotification:
            selectNotificationStream.add(notificationResponse.payload);
            break;
          case NotificationResponseType.selectedNotificationAction:
            if (notificationResponse.actionId == navigationActionId) {
              selectNotificationStream.add(notificationResponse.payload);
            }
            break;
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _notificationsReady = true;
  } catch (error, stack) {
    unawaited(reportCrash(error, stack, context: "запуск: уведомления"));
  }

  try {
    await dotenv.load(fileName: ".env");
  } catch (error, stack) {
    // Без ключа запросы уйдут анонимными — это медленнее, но это работает.
    unawaited(reportCrash(error, stack, context: "запуск: dotenv"));
  }

  // Толчки поднимаем до магазина состояния, но не ждём от них ничего: не
  // поднялись — приложение остаётся приложением, а напоминания за фоновой
  // задачей. Падать на запуске из-за службы уведомлений несоразмерно.
  final pushReady = await initPush();
  if (pushReady) {
    FirebaseMessaging.onBackgroundMessage(pushHandler);
    // То же сообщение при открытом приложении: система в этом случае фоновый
    // обработчик не зовёт, и без этой строки напоминание приходило бы всем,
    // кроме тех, кто держит приложение открытым.
    FirebaseMessaging.onMessage.listen((message) => pushHandler(message));
  }

  final store = await createReduxStore();

  // Ключ доставки не вечен и меняется молча: не перепривязав его, мы перестали
  // бы получать толчки без единой ошибки на экране.
  //
  // Стор к этой строке уже поднят с диска (см. createReduxStore) — иначе
  // `remindsFromServer` был бы значением по умолчанию и перепривязки не было бы
  // никогда. Без Firebase не трогаем ничего: `FirebaseMessaging.instance` без
  // поднятого приложения бросает, и до `runApp` дело бы не дошло.
  if (pushReady) {
    unawaited(refreshPushRegistration(wanted: store.state.settings.remindsFromServer));
    watchPushToken(wanted: () => store.state.settings.remindsFromServer);
  }

  runApp(MyApp(store));
  // Register to receive BackgroundFetch events after app is terminated.
  // Requires {stopOnTerminate: false, enableHeadless: true}
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

// [Android-only] This "Headless Task" is run when the Android app is terminated with `enableHeadless: true`
// Be sure to annotate your callback function to avoid issues in release mode on Flutter >= 3.3.0
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  final taskId = task.taskId;
  // Система отвела время и оно вышло: доделывать нечего, надо только ответить.
  if (task.timeout) {
    BackgroundFetch.finish(taskId);
    return;
  }

  try {
    // Своя изоляция: ни обработчиков падений, ни поднятых уведомлений в ней нет.
    installCrashReporting();
    await _ensureNotificationsReady();
    await _runBackgroundChecks();
  } finally {
    // Не ответив, получаем от системы всё более редкие пробуждения.
    BackgroundFetch.finish(taskId);
  }
}

bool _notificationsReady = false;

/// Поднимает уведомления там, где `main()` не выполнялся: в изоляции фоновой
/// задачи и толчка.
///
/// **В живом приложении не делает ничего.** Повторный `initialize` без
/// обработчика нажатий затирает тот, что поставил `main()`, — а толчок при
/// открытом приложении идёт через тот же `pushHandler`, и после первого же
/// напоминания нажатия на уведомления перестали бы куда-либо вести.
Future<void> _ensureNotificationsReady() async {
  if (_notificationsReady) return;
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  _notificationsReady = true;
}

/// Всё, о чём приложение напоминает само. Один перечень на оба пути — с живым
/// процессом и без него: пока их было два, чтения дня значились только во
/// втором, и тому, кто не выгружает приложение, не приходили вовсе.
///
/// Каждая проверка отдельно: сорвавшаяся не должна отменять следующие.
Future<void> _runBackgroundChecks({Future<void> Function()? beforePomyannik}) async {
  final checks = <Future<void> Function()>[
    () => _checkVersionAndNotify(""),
    _checkNewTextsAndNotify,
    if (beforePomyannik != null) beforePomyannik,
    _checkPomyannikAndNotify,
    _checkReadingAndNotify,
  ];
  for (final check in checks) {
    try {
      await check();
    } catch (error, stack) {
      unawaited(reportCrash(error, stack, context: "фоновая проверка"));
    }
  }
}

/// Толчок о поминальном дне.
///
/// **Приходит пустым.** Сервер говорит лишь, что сегодня у этого человека
/// поминальный день; текст складывается здесь, из своего зеркала, тем же
/// правилом `pomyannikVerdict`, что и без сети. Оттого напоминание с сервера и
/// напоминание от фоновой задачи выглядят одинаково — это одно и то же
/// напоминание, у которого разный будильник.
///
/// Ворота внутри правила остаются в силе: и «сегодня уже говорили», и время
/// суток, и «показывать ли имена». Толчок их не обходит — он только приходит
/// вовремя.
@pragma('vm:entry-point')
Future<void> pushHandler(RemoteMessage message) async {
  final kind = message.data["kind"];
  if (kind != "pomyannik" && kind != "reading") return;

  // Фоновый обработчик поднимается в своей изоляции: ни магазина состояния, ни
  // подключённых плагинов в ней нет, и уведомления надо поднять заново.
  await Firebase.initializeApp();
  await _ensureNotificationsReady();

  if (kind == "pomyannik") {
    await _checkPomyannikAndNotify();
  } else {
    await _checkReadingAndNotify();
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  // ignore: avoid_print
  // print('notification(${notificationResponse.id}) action tapped: '
  //     '${notificationResponse.actionId} with'
  //     ' payload: ${notificationResponse.payload}');
  // if (notificationResponse.input?.isNotEmpty ?? false) {
  //   // ignore: avoid_print
  //   print(
  //       'notification action tapped with input: ${notificationResponse.input}');
  // }
  final Uri url = Uri.parse('$apiBaseUrl/app/app.apk');
  if (await canLaunchUrl(url)) {
    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: "_blank",
    );
  }
}

Future _checkVersionAndNotify(String type) async {
  try {
    var version = await getVersion();
    // Об одной версии — один раз, а не каждый час (см. claimUpdateNotification).
    if (await claimUpdateNotification(version)) {
      // Show a notification after every 15 minute with the first
      // appearance happening a minute after invoking the method
      var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'updateChannelId',
        'updateNotificationChannel',
        channelDescription: 'Notifications about update',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        ticker: "update version ticker",
      );
      var iOSPlatformChannelSpecifics = new DarwinNotificationDetails();

      // initialise channel platform for both Android and iOS device.
      var platformChannelSpecifics = new NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSPlatformChannelSpecifics
      );
      await flutterLocalNotificationsPlugin.show(id++,
          'Уставные чтения',
          'Появилось новое обновление. Нажмите для загрузки.',
          // Адрес выпуска едет вместе с уведомлением: нажать на него могут
          // через час после проверки, и второй раз спрашивать сервер ради
          // одного адреса незачем.
          platformChannelSpecifics, payload: "$wantToGetUpdate ${updateUrl(version)}",
      );
    }
  } catch (error) {
    print("Не получена версия");
  }
}

/// Чтения дня в назначенный человеком час.
///
/// Свой канал, негромкий, как и у помянника: чтения дня — не то, ради чего
/// телефон должен вздрагивать, а отдельным каналом его можно приглушить, не
/// глуша уведомлений об обновлении.
Future<void> _checkReadingAndNotify() async {
  await checkReadingAndNotify(show: (body, payload) async {
    await flutterLocalNotificationsPlugin.show(
      // Постоянный номер: второй показ за день заменяет прежнее уведомление, а
      // не копит их стопкой.
      901,
      "Чтения дня",
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dayReadingChannelId',
          'dayReadingChannel',
          channelDescription: 'Чтения дня утром',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(presentSound: false),
      ),
      payload: payload,
    );
  });
}

/// Напоминание о поминальном дне.
///
/// Едет тем же колбэком, что и проверка новых текстов, — третьей периодической
/// задачи ради этого не заводим. Само решение, говорить ли, живёт в
/// `utils/pomyannik_reminders.dart`: тут только показ.
///
/// Канал свой и негромкий: обычная важность вместо `max` и без звука на iOS.
/// Напоминание о сороковом дне в восемь утра — не то, ради чего телефон должен
/// вздрагивать; отдельным каналом его вдобавок можно приглушить, не глуша
/// уведомлений об обновлении.
Future<void> _checkPomyannikAndNotify() async {
  await checkPomyannikAndNotify(show: (body, payload) async {
    await flutterLocalNotificationsPlugin.show(
      // Постоянный номер, а не id++: второй показ за день заменяет прежнее
      // уведомление, а не копит их стопкой.
      900,
      "Помянник",
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pomyannikChannelId',
          'pomyannikChannel',
          channelDescription: 'Напоминания о поминальных днях',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(presentSound: false),
      ),
      payload: payload,
    );
  });
}

// Едет на том же background_fetch-колбэке, что и _checkVersionAndNotify —
// не заводим отдельную вторую периодическую задачу ради батареи.
Future<void> _checkNewTextsAndNotify() async {
  try {
    final texts = await getLastTexts();
    if (texts.list.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final lastSeenId = prefs.getString(_lastSeenTextIdKey);
    final newest = texts.list.first;

    if (lastSeenId == null) {
      // Первый запуск фонового чекера на этом устройстве — не заваливаем
      // уведомлениями то, что уже было опубликовано раньше, просто
      // запоминаем текущую точку отсчёта.
      await prefs.setString(_lastSeenTextIdKey, newest.id);
      return;
    }
    if (lastSeenId == newest.id) return;

    final knownIndex = texts.list.indexWhere((t) => t.id == lastSeenId);
    final newItems = knownIndex == -1 ? texts.list : texts.list.sublist(0, knownIndex);
    if (newItems.isEmpty) return;

    await prefs.setString(_lastSeenTextIdKey, newest.id);

    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
      'newTextsChannelId',
      'newTextsChannel',
      channelDescription: 'Notifications about new texts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: "new texts ticker",
    );
    var iOSPlatformChannelSpecifics = new DarwinNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics
    );

    final isSingle = newItems.length == 1;
    await flutterLocalNotificationsPlugin.show(
      id++,
      isSingle ? newItems.first.name : 'Новые тексты',
      isSingle ? 'Добавлен новый текст. Нажмите, чтобы открыть.' : 'Добавлено новых текстов: ${newItems.length}',
      platformChannelSpecifics,
      payload: isSingle ? '$newTextPayloadPrefix${newItems.first.id}' : null,
    );
  } catch (error) {
    print("Не удалось проверить новые тексты");
  }
}

class MyApp extends StatefulWidget {
  final Store<AppState> store;

  MyApp(this.store);

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool _hasSkippedUpdate = false;

  void _handleTapboxChanged(bool val) {
    setState(() {
      _hasSkippedUpdate = val;
    });
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.green, brightness: brightness);
    final brandColor = brightness == Brightness.dark ? Colors.green.shade900 : Colors.green;
    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      textTheme: TextTheme(
        displayLarge: TextStyle(fontFamily: "OldStandard", fontSize: 16),
        displayMedium: TextStyle(fontFamily: "OldStandard", fontSize: 14),
        displaySmall: TextStyle(fontFamily: "OldStandard", fontSize: 12),
        headlineLarge: TextStyle(fontFamily: "OldStandard", fontSize: 16),
        headlineMedium: TextStyle(fontFamily: "OldStandard", fontSize: 14),
        headlineSmall: TextStyle(fontFamily: "OldStandard", fontSize: 12),
        labelLarge: TextStyle(fontFamily: "OldStandard", fontSize: 16),
        labelMedium: TextStyle(fontFamily: "OldStandard", fontSize: 14),
        labelSmall: TextStyle(fontFamily: "OldStandard", fontSize: 12),
        titleLarge: TextStyle(fontFamily: "OldStandard", fontSize: 16),
        titleMedium: TextStyle(fontFamily: "OldStandard", fontSize: 14),
        titleSmall: TextStyle(fontFamily: "OldStandard", fontSize: 12),
        bodyLarge: TextStyle(fontFamily: "OldStandard", fontSize: 16),
        bodyMedium: TextStyle(fontFamily: "OldStandard", fontSize: 14),
        bodySmall: TextStyle(fontFamily: "OldStandard", fontSize: 12),
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: brandColor,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(fontSize: 18.0, color: Colors.white),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
    // Разрешения на уведомления тут нет нарочно: его спрашивают там, где
    // человек включает напоминание (см. utils/notification_permission.dart).
    // Системное окно на первом запуске, поверх пустого экрана и без объяснения,
    // получало «нет» — а на Android второй отказ окончателен.
    _configureDidReceiveLocalNotificationSubject();
    _configureSelectNotificationSubject();
    // store = Store<AppState>(
    //     appReducer,
    //     initialState: AppState.init(),
    // );
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // Configure BackgroundFetch.
    await BackgroundFetch.configure(BackgroundFetchConfig(
        minimumFetchInterval: 60,
        stopOnTerminate: false,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.ANY
    ), (String taskId) async {  // <-- Event handler
      // This is the fetch-event callback.
      try {
        await _runBackgroundChecks(beforePomyannik: () async {
          // Зеркало обновляется отсюда, а не из фоновой задачи: там сессию
          // продлить нечем — окна входа показать некому.
          if (await remindersEnabled()) {
            await refreshPomyannikMirror(appStore?.state.auth.userId);
          }
        });
      } finally {
        // IMPORTANT:  You must signal completion of your task or the OS can punish your app
        // for taking too long in the background.
        BackgroundFetch.finish(taskId);
      }
    }, (String taskId) async {
      // Время вышло: отвечаем и на это, иначе система урежет пробуждения.
      BackgroundFetch.finish(taskId);
    });
    // print('[BackgroundFetch] configure success: $status');

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  void _configureDidReceiveLocalNotificationSubject() {

  }

  void _configureSelectNotificationSubject() {
    selectNotificationStream.stream.listen((String? payload) async {
      // Уведомление о чтениях ведёт в службу дня.
      if (payload != null && payload.startsWith("reading:")) {
        final alias = payload.substring("reading:".length);
        if (alias.isNotEmpty) {
          navigatorKey.currentState?.pushNamed("/days", arguments: alias);
        }
        return;
      }
      if (payload != null && payload.startsWith(wantToGetUpdate)) {
        // Уведомления, показанные прежней версией приложения, адреса не несут —
        // им остаётся прежний, свой.
        final String named = payload.substring(wantToGetUpdate.length).trim();
        final Uri url = Uri.parse(
            named.isEmpty ? '$apiBaseUrl/app/app.apk' : named);
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: "_blank",
          );
        } else {
          throw new Exception("Cannot launch update");
        }
      }
      if (payload != null && payload.contains("download")) {
        var [v, path] = payload.split(" - ");
        print(path);
        // final String filePath = Uri(
        //   scheme: 'file',
        //   path: path,
        // ).toFilePath();
        //
        // final Uri fileUri = Uri(
        //   scheme: 'file',
        //   path: filePath,
        // );
        // print(fileUri);
        // print(filePath);

        const platform = MethodChannel('su.typikon.typikon/utils');
        platform.invokeMethod("openFile", [path, "application/x-fictionbook"]);
        // OpenFilex.open(path);
        // launchUrl(fileUri);
        // OpenAppFile.open(path);
      }
      if (payload != null && payload.startsWith(newTextPayloadPrefix)) {
        final textId = payload.substring(newTextPayloadPrefix.length);
        navigatorKey.currentState?.pushNamed("/reading", arguments: textId);
      }
      if (payload != null && payload.startsWith(pomyannikPayloadPrefix)) {
        final what = payload.substring(pomyannikPayloadPrefix.length);
        // «upcoming» — весь список ближайшего; иначе это лицо, о котором речь.
        navigatorKey.currentState?.pushNamed(
          what == "upcoming" ? "/pomyannik/upcoming" : "/pomyannik",
          arguments: what == "upcoming" ? null : what,
        );
      }
    });
  }

  @override
  void dispose() {
    didReceiveLocalNotificationStream.close();
    selectNotificationStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreProvider(
        store: widget.store,
        child: StoreBuilder<AppState>(
            builder: (context, store) {
              return MaterialApp(
                navigatorKey: navigatorKey,
                navigatorObservers: [routeObserver],
                title: 'Typikon',
                localizationsDelegates: [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: [
                  const Locale('ru'),
                ],
                restorationScopeId: "root",
                initialRoute: '/',
                // Разбор маршрутов живёт в lib/routes.dart: он же сверяется
                // тестом с перечнем пунктов меню.
                onGenerateRoute: (settings) => generateRoute(
                  settings,
                  hasSkippedUpdate: _hasSkippedUpdate,
                  skipUpdateWindow: _handleTapboxChanged,
                ),
                // generateRoute отвечает null на незнакомое имя и на негодный
                // аргумент; без этой строки такой переход был исключением.
                onUnknownRoute: (settings) => MaterialPageRoute(
                  settings: settings,
                  builder: (context) => const NotFoundPage(),
                ),
                theme: _buildTheme(Brightness.light),
                darkTheme: _buildTheme(Brightness.dark),
                themeMode: store.state.settings.themeMode,
              );
            },
        ),
    );
  }
}