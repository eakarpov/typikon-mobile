import 'package:typikon/apiMapper/version.dart';
import 'package:typikon/dto/version.dart';
import 'package:typikon/version.dart';
import 'package:url_launcher/url_launcher.dart';
import "package:google_fonts/google_fonts.dart";

import "../dto/text.dart";
import "../apiMapper/reading.dart";
import '../apiMapper/calendar.dart';
import '../dto/calendar.dart';
import "../dto/day.dart";
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MainPage extends StatefulWidget {
  const MainPage(context, {
    super.key,
    required this.hasSkippedUpdate,
    required this.skipUpdateWindow,
  });

  final bool hasSkippedUpdate;
  final ValueChanged<bool> skipUpdateWindow;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with RestorationMixin {
  late Future<DayResult> currentDay;
  late Future<Version> version;
  late Future<ReadingList> lastTexts;

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
    // currentDay = getCalendarDay(
    //     DateFormat('yyyy-MM-dd').format(
    //         // DateTime.now().subtract(const Duration(days: 13))
    //         DateTime.now()
    //     )
    // );
    currentDay = getCalendarReadingForDate(
        DateTime.now().subtract(const Duration(days: 13)).millisecondsSinceEpoch
        // DateFormat('yyyy-MM-dd').format(
        //     DateTime.now().subtract(const Duration(days: 13))
        // )
    );
    lastTexts = getLastTexts();
    version = getVersion();
    version.then((value) => {
      if ((value.major > majorVersion || value.minor > minorVersion) && !widget.hasSkippedUpdate) {
        showAlert(context, value)
      }
    });
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
      currentDay = getCalendarReadingForDate(picked.subtract(const Duration(days: 13)).millisecondsSinceEpoch);
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
      currentDay = getCalendarReadingForDate(
          newSelectedDate.subtract(const Duration(days: 13)).millisecondsSinceEpoch
          // DateFormat('yyyy-MM-dd').format(
          //     newSelectedDate.subtract(const Duration(days: 13))
              // newSelectedDate
          // )
      );
    }
  }

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

  void onSkipUpdate(BuildContext context) async {
    widget.skipUpdateWindow(true);
    Navigator.of(context).pop();
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
              onPressed: () => onSkipUpdate(context),
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

  void onGoToCalculator() {
    Navigator.pushNamed(context, "/calculator");
  }

  @override
  Widget build(BuildContext context) {
    DateFormat format = DateFormat("dd.MM.yyyy");
    String value = _selectedDate.isRegistered ? format.format(_selectedDate.value) : "Не задано";
    return Scaffold(
      backgroundColor: Colors.white,
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
      body: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height),
            child: SingleChildScrollView(
              child: Column(mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    height: 170.0,
                    child: Padding(
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
                          Text("В данных момент доступна библиотека книг и текстов, подборка чтений по дням Цветной Триоди,"
                              "календарные чтения на каждый день года, поиск по названию текста,"
                              "а также просмотр памятей на день. Ждите новых обновлений!", textAlign: TextAlign.justify,),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onGoToLibrary,
                    child: Text("Посмотреть тексты в библиотеке"),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 12.0),
                    child: Text(
                      "Чтения Пролога на выбранную дату",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height),
                    child: FutureBuilder<DayResult>(
                      future: currentDay,
                      builder: (context, future) {
                        if (future.hasData) {
                          if (future.data == null) return SizedBox.shrink();
                          DayTexts? data = future.data?.data;
                          if (data == null) return SizedBox.shrink();
                          DayTextsParts? song6 = data?.song6;
                          if (song6 == null) return SizedBox.shrink();
                          List<DayTextsPart>? list = song6?.items;
                          if (list == null) return SizedBox.shrink();
                          return ListView.builder(
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  itemCount: list.length,
                                  physics: new NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    final item = list[index];
                                    return Container(
                                      child: ListTile(
                                        title: Text(
                                            item.text?.name ?? "Без названия",
                                          style: TextStyle(fontFamily: "OldStandard", color: Colors.red),
                                        ),
                                        onTap: () => {
                                          Navigator.pushNamed(context, "/reading", arguments: item.text?.id)
                                        },
                                      ),
                                    );
                                  },
                            );
                        } else if (future.hasError) {
                          return SizedBox(
                            height: 20,
                            child: Text('${future.error}'),
                          );
                        }
                        return SizedBox(
                          height: 20,
                          child: Container(
                            color: const Color(0xffffffff),
                            child: Positioned.fill(
                              child: Align(
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // TextButton(
                  //   onPressed: onGoToCalculator,
                  //   child: Text("Прочитать собранные чтения дня Триоди и Минеи (работает в пределах Цветной Триоди)"),
                  // ),
                  Text("Последние добавленные тексты", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height),
                    child: FutureBuilder<ReadingList>(
                        future: lastTexts,
                        builder: (context, future) {
                          if (future.hasData) {
                            List<Reading> list = future.data!.list;
                            return ListView.builder(
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  physics: new NeverScrollableScrollPhysics(),
                                  itemCount: list.length,
                                  itemBuilder: (context, index) {
                                    final item = list[index];
                                    return Container(
                                      child: ListTile(
                                        title: Text(item.name ?? "test", style: TextStyle(fontFamily: "OldStandard", color: Colors.red),),
                                        subtitle: Text(
                                            "Обновлено ${item.updatedAt.day}.${item.updatedAt.month}.${item.updatedAt.year}" ?? "test"),
                                        onTap: () => {
                                          Navigator.pushNamed(context, "/reading", arguments: item.id)
                                        },
                                      ),
                                    );
                                  },
                            );
                          }
                          return Container(
                            color: const Color(0xffffffff),
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
            ),
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
              child: Text('Типикон ($majorVersion.$minorVersion.0)'),
            ),
            ListTile(
              title: const Text('Главная страница', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/",
              onTap: () {
                Navigator.pushNamed(context, "/");
              },
            ),
            ListTile(
              title: const Text('Поиск', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/search",
              onTap: () {
                Navigator.pushNamed(context, "/search");
              },
            ),
            ListTile(
              title: const Text('Библиотека', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/library",
              onTap: () {
                Navigator.pushNamed(context, "/library");
              },
            ),
            ListTile(
              title: const Text('Пятидесятница', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/penticostarion",
              onTap: () {
                Navigator.pushNamed(context, "/penticostarion");
              },
            ),
            ListTile(
              title: const Text('Триодион', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/triodion",
              onTap: () {
                Navigator.pushNamed(context, "/triodion");
              },
            ),
            ListTile(
              title: const Text('Чтения на календарный день', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/months",
              onTap: () {
                Navigator.pushNamed(context, "/months");
              },
            ),
            ListTile(
              title: const Text('Калькулятор чтений на день', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/calculator",
              onTap: () {
                Navigator.pushNamed(context, "/calculator");
              },
            ),
            ListTile(
              title: const Text('Памяти на день', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/dneslov/memories",
              onTap: () {
                Navigator.pushNamed(context, "/dneslov/memories");
              },
            ),
            ListTile(
              title: const Text('Настройки', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/settings",
              onTap: () {
                Navigator.pushNamed(context, "/settings");
              },
            ),
            if (widget.hasSkippedUpdate) ListTile(
              title: const Text("Обновить приложение", style: TextStyle(fontSize: 14.0),),
              onTap: () => onLoadUpdate(context),
            ),
          ],
        ),
      ),
    );
  }
}