import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';

import 'package:typikon/store/models/models.dart';
import 'package:typikon/apiMapper/calendar.dart';
import 'package:typikon/dto/calendar.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/models/models.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage(context, {super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  late Future<CalendarDay> currentDay;

  @override
  String? get restorationId => "test";

  // final RestorableDateTime _selectedDate = RestorableDateTime(DateTime.now());
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
        DateFormat('yyyy-MM-dd').format(
            DateTime.now()
                // .subtract(const Duration(days: 13))
        )
    );
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    // registerForRestoration(_selectedDate, 'selected_date');
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
    DateTime now = new DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      locale: const Locale("ru", "RU"),
      initialDate: StoreProvider.of<AppState>(context).state.common.date,
      // initialDate: DateTime.fromMillisecondsSinceEpoch(_selectedDate.value.millisecondsSinceEpoch! as int),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialEntryMode: DatePickerEntryMode.calendar,
      initialDatePickerMode: DatePickerMode.day,
      // helpText: 'Select booking date',
      // cancelText: 'Not now',
      // confirmText: 'Book',
    );
    if (picked != null && picked != StoreProvider.of<AppState>(context).state.common.date) {
      // setState(() {
      //   _selectedDate.value = picked;
      // });
      StoreProvider.of<AppState>(context).dispatch(
          ChangeCommonDateAction(picked)
      );
      currentDay = getCalendarDay(
          DateFormat('yyyy-MM-dd').format(
              picked
                  // .subtract(const Duration(days: 13))
          )
      );
    }
  }

  void _showSelectDate(BuildContext context) {
    return buildMaterialDatePicker(context);
  }

  void _selectDate(DateTime? newSelectedDate) {
    if (newSelectedDate != null) {
      // setState(() {
      //   _selectedDate.value = newSelectedDate;
      // });
      StoreProvider.of<AppState>(context).dispatch(
          ChangeCommonDateAction(newSelectedDate)
      );
      currentDay = getCalendarDay(
          DateFormat('yyyy-MM-dd').format(
              newSelectedDate
                  // .subtract(const Duration(days: 13))
          )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    DateFormat format = DateFormat("dd.MM.yyyy");
    // String value = _selectedDate.isRegistered ? format.format(_selectedDate.value) : "Не задано";
    String value = StoreProvider.of<AppState>(context).state.common.date != null
        ? format.format(StoreProvider.of<AppState>(context).state.common.date)
        : "Не задано";
    return Scaffold(
      appBar: AppBar(
        title: Text(value, style: TextStyle(fontFamily: "OldStandard")),
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
      body: Container(
        color: const Color(0xffffffff),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<CalendarDay>(
          future: currentDay,
          builder: (context, future) {
            print(future);
            if (future.hasData) {
              return SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        if (future.data!.kathisma1 != null) Column(
                          children: [
                            Text("По седальнах первой кафизмы", style: TextStyle(fontWeight: FontWeight.bold)),
                            ...future.data!.kathisma1!.items!.map((item) => Column(
                              children: [
                                Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  item.content,
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                      fontFamily: "OldStandard",
                                      fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                        if (future.data!.kathisma2 != null) Column(
                          children: [
                            Text("По седальнах второй кафизмы", style: TextStyle(fontWeight: FontWeight.bold)),
                            ...future.data!.kathisma2!.items!.map((item) => Column(
                              children: [
                                Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  item.content,
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                      fontFamily: "OldStandard",
                                      fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                        if (future.data!.kathisma3 != null) Column(
                          children: [
                            Text("По седальнах третьей кафизмы", style: TextStyle(fontWeight: FontWeight.bold)),
                            ...future.data!.kathisma3!.items!.map((item) => Column(
                              children: [
                                Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  item.content,
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                      fontFamily: "OldStandard",
                                      fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                        if (future.data!.ipakoi != null) Column(
                          children: [
                            Text("По ипакои", style: TextStyle(fontWeight: FontWeight.bold)),
                            ...future.data!.ipakoi!.items!.map((item) => Column(
                              children: [
                                Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  item.content,
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                      fontFamily: "OldStandard",
                                      fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                        if (future.data!.polyeleos != null) Column(
                          children: [
                            Text("По седальнах полиелея", style: TextStyle(fontWeight: FontWeight.bold)),
                            ...future.data!.polyeleos!.items!.map((item) => Column(
                              children: [
                                Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  item.content,
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                      fontFamily: "OldStandard",
                                      fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                        if (future.data!.song3 != null) Column(
                          children: [
                            Text("По седальнах третьей песни", style: TextStyle(fontWeight: FontWeight.bold)),
                            ...future.data!.song3!.items!.map((item) => Column(
                              children: [
                                Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  item.content,
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                      fontFamily: "OldStandard",
                                      fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                        if (future.data!.song6 != null) Column(
                          children: [
                            Text("По кондаке и икосе шестой песни", style: TextStyle(fontWeight: FontWeight.bold)),
                            ...future.data!.song6!.items!.map((item) => Column(
                              children: [
                                Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  item.content,
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                      fontFamily: "OldStandard",
                                      fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                        if (future.data!.apolutikaTroparia != null) Column(
                          children: [
                            Text("По отпустительным тропарям", style: TextStyle(fontWeight: FontWeight.bold)),
                            ...future.data!.apolutikaTroparia!.items!.map((item) => Column(
                              children: [
                                Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  item.content,
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                      fontFamily: "OldStandard",
                                      fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                        if (future.data!.before1h != null) Column(
                          children: [
                            Text("Перед первым часом", style: TextStyle(fontWeight: FontWeight.bold)),
                            ...future.data!.before1h!.items!.map((item) => Column(
                              children: [
                                Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  item.content,
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                      fontFamily: "OldStandard",
                                      fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
                                  ),
                                ),
                              ],
                            )),
                          ],
                        ),
                      ],
                    ),
                ),
              );
            } else if (future.hasError) {
              return Center(child: Text('Для этой даты формирование выдачи недоступно'));
            }
            return Container(
              color: const Color(0xffffffff),
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
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
    );
  }
}