import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';

import 'package:typikon/apiMapper/dneslov/calendar.dart';
import 'package:typikon/dto/dneslov/calendar.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/models/models.dart';

class CurrentDayMemoriesPage extends StatefulWidget {
  const CurrentDayMemoriesPage(context, {super.key});

  @override
  State<CurrentDayMemoriesPage> createState() => _CurrentDayMemoriesPageState();
}

class _CurrentDayMemoriesPageState extends State<CurrentDayMemoriesPage> {
  late Future<CalendarDayD> currentDay;

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
    // currentDay = getCalendarDayD(
    //     DateFormat('dd.MM.yyyy').format(
    //         DateTime.now().subtract(const Duration(days: 13))
    //     )
    // );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var val = StoreProvider.of<AppState>(context).state.common.date != null
        ? StoreProvider.of<AppState>(context).state.common.date!.subtract(const Duration(days: 13))
        : DateTime.now().subtract(const Duration(days: 13));
    var valFormat = DateFormat('dd.MM.yyyy').format(val);
    currentDay = getCalendarDayD(valFormat);
    // StoreProvider.of<AppState>(context).dispatch(FetchItemsAction());
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
      currentDay = getCalendarDayD(
          DateFormat('dd.MM.yyyy').format(
              picked.subtract(const Duration(days: 13))
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
      currentDay = getCalendarDayD(
          DateFormat('dd.MM.yyyy').format(
              newSelectedDate.subtract(const Duration(days: 13))
          )
      );
    }
  }

  void onOpenEventDneslov(CalendarDayDItem item, String calendarString) {
    if (StoreProvider.of<AppState>(context).state.common.date != null ) {
      final date = DateFormat('dd.MM.yyyy').format(
        // _selectedDate.value.subtract(const Duration(days: 13))
          StoreProvider.of<AppState>(context).state.common.date.subtract(const Duration(days: 13))
      );
      Uri myUrl = Uri.parse("https://dneslov.org/${item.slug}/${item.eventId}?c=${calendarString}&d=ю$date");
      launchUrl(myUrl);
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
        child: FutureBuilder<CalendarDayD>(
              future: currentDay,
              builder: (context, future) {
                if (future.hasData) {
                  List<CalendarDayDItem> list = future.data!.list;
                  return ListView.builder(
                    scrollDirection: Axis.vertical,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return Container(
                        child: ListTile(
                          onTap: () => {
                            Navigator.pushNamed(
                                context, "/saints", arguments: item.slug)
                          },
                          leading: Text(item.saintTitle??"св"),
                          title: Text(item.title??""),
                          subtitle: Text(item.happenedAt??""),
                        ),
                      );
                    },
                  );
                } else if (future.hasError) {
                  return Text('${future.error}');
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