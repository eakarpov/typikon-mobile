import 'package:typikon/apiMapper/version.dart';
import 'package:typikon/dto/version.dart';
import 'package:typikon/version.dart';
import 'package:url_launcher/url_launcher.dart';

import '../apiMapper/calendar.dart';
import '../dto/calendar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MainPage extends StatefulWidget {
  const MainPage(context, {super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with RestorationMixin {
  late Future<CalendarDay> currentDay;
  late Future<Version> version;

  @override
  String? get restorationId => "test";

  final RestorableDateTime _selectedDate = RestorableDateTime(DateTime.now());
  // late final RestorableRouteFuture<DateTime?> _restorableDatePickerRouteFuture =
  // RestorableRouteFuture<DateTime?>(
  //   onComplete: _selectDate,
  //   onPresent: (NavigatorState navigator, Object? arguments) {
  //     return navigator.restorablePush(
  //       _datePickerRoute,
  //       arguments: _selectedDate.value.millisecondsSinceEpoch,
  //     );
  //   },
  // );


  @override
  void initState() {
    super.initState();
    currentDay = getCalendarDay(
        DateFormat('dd.MM.yyyy').format(
            DateTime.now().subtract(const Duration(days: 13))
        )
    );
    version = getVersion();
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_selectedDate, 'selected_date');
    // registerForRestoration(
    //     _restorableDatePickerRouteFuture, 'date_picker_route_future');
  }

  // static Route<DateTime> _datePickerRoute(BuildContext context, Object? arguments) {
  //   return DialogRoute<DateTime>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       // return showDatePicker(
  //       //     context: context,
  //       //     initialDate: DateTime.fromMillisecondsSinceEpoch(arguments! as int),
  //       //     firstDate: DateTime(1970),
  //       //     lastDate: DateTime(2026));
  //       // );
  //       return DatePickerDialog(
  //         cancelText: "Отменить",
  //         confirmText: "Выбрать",
  //         helpText: "Выбрать дату",
  //         // locale: const Locale("fr", "FR"),
  //         restorationId: 'date_picker_dialog',
  //         initialEntryMode: DatePickerEntryMode.calendarOnly,
  //         initialDate: DateTime.fromMillisecondsSinceEpoch(arguments! as int),
  //         firstDate: DateTime(1970),
  //         lastDate: DateTime(2026),
  //       );
  //     },
  //   );
  // }

  void buildMaterialDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      locale: const Locale("ru", "RU"),
      initialDate: DateTime.fromMillisecondsSinceEpoch(_selectedDate.value.millisecondsSinceEpoch! as int),
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
      initialEntryMode: DatePickerEntryMode.calendar,
      initialDatePickerMode: DatePickerMode.day,
      // helpText: 'Select booking date',
      // cancelText: 'Not now',
      // confirmText: 'Book',
    );
    if (picked != null && picked != _selectedDate.value) {
      setState(() {
        _selectedDate.value = picked;
      });
    }
  }

  void _showSelectDate(BuildContext context) {
      return buildMaterialDatePicker(context);
  }

  void _selectDate(DateTime? newSelectedDate) {
    if (newSelectedDate != null) {
      setState(() {
        _selectedDate.value = newSelectedDate;
      });
      currentDay = getCalendarDay(
          DateFormat('dd.MM.yyyy').format(
              newSelectedDate.subtract(const Duration(days: 13))
          )
      );
    }
  }

  Widget textSection = Container(
    padding: const EdgeInsets.all(32),
    child: const Text(
      'Lake Oeschinen lies at the foot of the Blüemlisalp in the Bernese '
          'Alps. Situated 1,578 meters above sea level, it is one of the '
          'larger Alpine Lakes. A gondola ride from Kandersteg, followed by a '
          'half-hour walk through pastures and pine forest, leads you to the '
          'lake, which warms to 20 degrees Celsius in the summer. Activities '
          'enjoyed here include rowing, and riding the summer toboggan run.',
      softWrap: true,
    ),
  );

  void onLoadUpdate(BuildContext context) async {
    Navigator.of(context).pop();
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

  void showAlert(BuildContext context, Version value) {
    var major = value.major;
    var minor = value.minor;
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Обновление'),
          content: Text('Появилось новое обновление: Версия $major.$minor'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Пропустить'),
            ),
            TextButton(
              onPressed: () => onLoadUpdate(context),
              child: const Text('Загрузить'),
            ),
          ],
    ));
  }

  void onGoToLibrary() {
    Navigator.pushNamed(context, "/library");
  }

  @override
  Widget build(BuildContext context) {
    DateFormat format = DateFormat("dd.MM.yyyy");
    String value = _selectedDate.isRegistered ? format.format(_selectedDate.value) : "Не задано";
    version.then((value) => {
      if (value.major > majorVersion || value.minor > minorVersion) {
        showAlert(context, value)
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(value),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.calendar_today,
              color: Colors.white,
            ),
            onPressed: () {
              _showSelectDate(context);
              // _restorableDatePickerRouteFuture.present();
            },
          )
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: FutureBuilder<CalendarDay>(
                future: currentDay,
                builder: (context, future) {
                  if (future.hasData) {
                    List<CalendarDayItem> list = future.data!.list;
                    print(list.length.toString());
                    return textSection;
                  } else if (future.hasError) {
                    return Column(
                      children: [
                        Text('${future.error}'),
                        Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 12.0),
                                  child: Text(
                                    "Добро пожаловать",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text("Приложение в разработке. "
                                    "В данных момент доступна библиотека книг и текстов. "
                                    "Ждите новых обновлений."),
                              ],
                            ),
                        ),
                        TextButton(
                            onPressed: onGoToLibrary,
                            child: Text("Посмотреть тексты в библиотеке"),
                        ),
                      ],
                    );
                  }
                  return Container(
                    color: const Color(0xffCCCCCC),
                    width: double.infinity,
                    height: double.infinity,
                    child: Positioned.fill(
                      child: Align(
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                    ),
                  );
                },
              ),
          ),
        ],
      ),
      drawer: Drawer(
        // Add a ListView to the drawer. This ensures the user can scroll
        // through the options in the drawer if there isn't enough vertical
        // space to fit everything.
        child: ListView(
          // Important: Remove any padding from the ListView.
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green,
              ),
              child: Text('Меню приложения'),
            ),
            ListTile(
              title: const Text('Главная страница'),
              selected: ModalRoute.of(context)?.settings.name == "/",
              onTap: () {
                Navigator.pushNamed(context, "/");
              },
            ),
            ListTile(
              title: const Text('Библиотека'),
              selected: ModalRoute.of(context)?.settings.name == "/library",
              onTap: () {
                Navigator.pushNamed(context, "/library");
              },
            ),
          ],
        ),
      ),
    );
  }
}