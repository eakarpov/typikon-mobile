import "dart:ui";
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import "package:google_fonts/google_fonts.dart";
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import "package:background_fetch/background_fetch.dart";
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/pages/outside_page.dart';
import 'package:typikon/pages/signs_page.dart';
// import 'package:workmanager/workmanager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import "version.dart";

import "package:typikon/apiMapper/version.dart";
import 'package:typikon/pages/book_page.dart';
import 'package:typikon/pages/library_page.dart';
import 'package:typikon/pages/main_page.dart';
import 'package:typikon/pages/text_page.dart';
import 'package:typikon/pages/current_day_memories_page.dart';
import 'package:typikon/pages/settings_page.dart';
import 'package:typikon/pages/calculator_page.dart';
import 'package:typikon/pages/months_page.dart';
import 'package:typikon/pages/month_page.dart';
import 'package:typikon/pages/days_page.dart';
import 'package:typikon/pages/search_page.dart';
import 'package:typikon/pages/triodion_page.dart';
import 'package:typikon/pages/penticostarion_page.dart';
import 'package:typikon/pages/saint_page.dart';
import 'package:typikon/pages/place_page.dart';
import 'package:typikon/pages/favourite_page.dart';
import 'package:typikon/pages/contact_page.dart';
import 'package:typikon/pages/resources_page.dart';

import "package:typikon/store/rootReducer.dart";
import "package:typikon/store/index.dart";
import "package:typikon/store/actions/actions.dart";
import "package:typikon/store/store.dart";

int id = 0;

const String navigationActionId = 'id_3';

const String versionPeriodCheck = "simplePeriodicTask";

const String versionCheck = "simpleTask";

const String wantToGetUpdate = "wantToGetUpdate";

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

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

  await dotenv.load(fileName: ".env");
  // Workmanager().initialize(
  //     callbackDispatcher, // The top level function, aka callbackDispatcher
  //     isInDebugMode: true // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
  // );
  // // Workmanager().registerOneOffTask(
  // //   "version-checker-start",
  // //   versionCheck,
  // // );
  // Workmanager().registerPeriodicTask(
  //   "version-checker",
  //
  //   //This is the value that will be
  //   // returned in the callbackDispatcher
  //   versionPeriodCheck,
  //
  //   // When no frequency is provided
  //   // the default 15 minutes is set.
  //   // Minimum frequency is 15 min.
  //   // Android will automatically change
  //   // your frequency to 15 min
  //   // if you have configured a lower frequency.
  //   frequency: Duration(minutes: 15),
  // );
  final store = await createReduxStore();
  runApp(MyApp(store));
  // Register to receive BackgroundFetch events after app is terminated.
  // Requires {stopOnTerminate: false, enableHeadless: true}
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

// [Android-only] This "Headless Task" is run when the Android app is terminated with `enableHeadless: true`
// Be sure to annotate your callback function to avoid issues in release mode on Flutter >= 3.3.0
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  String taskId = task.taskId;
  bool isTimeout = task.timeout;
  await _checkVersionAndNotify("");
  // if (isTimeout) {
  //   // This task has exceeded its allowed running-time.
  //   // You must stop what you're doing and immediately .finish(taskId)
  //   print("[BackgroundFetch] Headless task timed-out: $taskId");
  //   BackgroundFetch.finish(taskId);
  //   return;
  // }
  // print('[BackgroundFetch] Headless event received.');
  // Do your work here...
  BackgroundFetch.finish(taskId);
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
  final Uri url = Uri.parse('https://typikon.su/app/app.apk');
  if (await canLaunchUrl(url)) {
    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: "_blank",
    );
  }
}

@pragma('vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  // Workmanager().executeTask((task, inputData) async {
  //   switch (task) {
  //     case versionCheck:
  //     case versionPeriodCheck:
  //       await _checkVersionAndNotify();
  //       return Future.value(true);
  //     default:
  //       return Future.value(true);
  //   }
  // });
}

Future _checkVersionAndNotify(String type) async {
  try {
    var version = await getVersion();
    if (version.major > majorVersion || version.minor > minorVersion) {
      // Show a notification after every 15 minute with the first
      // appearance happening a minute after invoking the method
      var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'updateChannelId',
        'updateNotificationChannel',
        channelDescription: 'Notifications about update',
        importance: Importance.max,
        priority: Priority.high,
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
          platformChannelSpecifics, payload: wantToGetUpdate,
      );
    }
  } catch (error) {
    print("Не получена версия");
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
  bool _notificationsEnabled = false;

  void _handleTapboxChanged(bool val) {
    setState(() {
      _hasSkippedUpdate = val;
    });
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _isAndroidPermissionGranted();
    _requestPermissions();
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
    int status = await BackgroundFetch.configure(BackgroundFetchConfig(
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
      await _checkVersionAndNotify("");
      // print("[BackgroundFetch] Event received $taskId");
      // IMPORTANT:  You must signal completion of your task or the OS can punish your app
      // for taking too long in the background.
      BackgroundFetch.finish(taskId);
    });
    // print('[BackgroundFetch] configure success: $status');

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  Future<void> _isAndroidPermissionGranted() async {
    if (Platform.isAndroid) {
      final bool granted = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled() ??
          false;

      setState(() {
        _notificationsEnabled = granted;
      });
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final bool? grantedNotificationPermission = await androidImplementation?.requestNotificationsPermission();
      setState(() {
        _notificationsEnabled = grantedNotificationPermission ?? false;
      });
    }
  }

  void _configureDidReceiveLocalNotificationSubject() {

  }

  void _configureSelectNotificationSubject() {
    selectNotificationStream.stream.listen((String? payload) async {
      if (payload == wantToGetUpdate) {
        final Uri url = Uri.parse('https://typikon.su/app/app.apk');
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
      // await Navigator.of(context).push(MaterialPageRoute<void>(
      //   builder: (BuildContext context) => LibraryPage(context),
      // ));
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
            onInit: (store) => store.dispatch(FetchItemsAction()),
            builder: (context, store) {
              return MaterialApp(
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
                onGenerateRoute: (RouteSettings settings) {
                  final arguments = settings.arguments;
                  switch (settings.name) {
                    case '/library':
                      if (arguments is String) {
                        return MaterialPageRoute(
                          builder: (context) {
                            return BookPage(
                              context,
                              id: arguments,
                            );
                          },
                        );
                      } else {
                        return MaterialPageRoute(
                          builder: (context) {
                            return LibraryPage(context);
                          },
                        );
                      }
                    case "/reading":
                      if (arguments is String) {
                        return MaterialPageRoute(
                          builder: (context) {
                            return TextPage(
                              context,
                              id: arguments,
                            );
                          },
                        );
                      }
                      return null;
                    case "/settings":
                      return MaterialPageRoute(
                        builder: (context) {
                          return SettingsPage(
                            context,
                          );
                        },
                      );
                    case "/calculator":
                      return MaterialPageRoute(
                        builder: (context) {
                          return CalculatorPage(
                            context,
                          );
                        },
                      );
                    case "/saints":
                      if (arguments is String) {
                        return MaterialPageRoute(
                          builder: (context) {
                            return SaintPage(
                              context,
                              id: arguments,
                            );
                          },
                        );
                      }
                    case "/places":
                      if (arguments is String) {
                        return MaterialPageRoute(
                          builder: (context) {
                            return PlacePage(
                              context,
                              id: arguments,
                            );
                          },
                        );
                      }
                    case "/triodion":
                      return MaterialPageRoute(
                        builder: (context) {
                          return TriodionPage(
                            context,
                          );
                        },
                      );
                    case "/penticostarion":
                      return MaterialPageRoute(
                        builder: (context) {
                          return PenticostarionPage(
                            context,
                          );
                        },
                      );
                    case "/search":
                      return MaterialPageRoute(
                        builder: (context) {
                          return SearchPage(
                            context,
                          );
                        },
                      );
                    case "/days":
                      if (arguments is String) {
                        return MaterialPageRoute(
                          builder: (context) {
                            return DaysPage(
                              context,
                              id: arguments,
                            );
                          },
                        );
                      }
                    case "/months":
                      if (arguments is String) {
                        return MaterialPageRoute(
                          builder: (context) {
                            return MonthPage(
                              context,
                              id: arguments,
                            );
                          },
                        );
                      } else {
                        return MaterialPageRoute(
                          builder: (context) {
                            return MonthsPage(context);
                          },
                        );
                      }
                    case "/favourites":
                      return MaterialPageRoute(
                        builder: (context) {
                          return FavouritePage(
                            context,
                          );
                        },
                      );
                    case "/contact":
                      return MaterialPageRoute(
                        builder: (context) {
                          return ContactPage(
                            context,
                          );
                        },
                      );
                    case "/dneslov/memories":
                      return MaterialPageRoute(
                        builder: (context) {
                          return CurrentDayMemoriesPage(context);
                        },
                      );
                    case "/resources":
                      return MaterialPageRoute(
                        builder: (context) {
                          return ResourcesPage(context);
                        },
                      );
                    case "/outside":
                      return MaterialPageRoute(
                        builder: (context) {
                          return OutsidePage(context);
                        },
                      );
                    case "/signs":
                      return MaterialPageRoute(
                        builder: (context) {
                          return SignsPage(context);
                        },
                      );
                    case "/":
                      return MaterialPageRoute(
                        builder: (context) {
                          return MainPage(
                            context,
                            hasSkippedUpdate: _hasSkippedUpdate,
                            skipUpdateWindow: _handleTapboxChanged,
                          );
                        },
                      );
                    default:
                      return null;
                  }
                },
                theme: ThemeData(
                  // primarySwatch: Colors.green,
                  colorSchemeSeed: Colors.green,
                  // textTheme: GoogleFonts.latoTextTheme(
                  //   Theme.of(context).textTheme,
                  // ),
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
                  scaffoldBackgroundColor: const Color(0xFFFFFFFF),
                  appBarTheme: AppBarTheme(
                      backgroundColor: Colors.green,
                      titleTextStyle: TextStyle(fontSize: 18.0)
                  )
                ),
              );
            },
        ),
    );
  }
}