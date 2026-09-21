import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:typikon/apiMapper/dneslov/calendar.dart';
import 'package:typikon/dto/dneslov/calendar.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/components/api_error_view.dart';

class CurrentDayMemoriesPage extends StatefulWidget {
  const CurrentDayMemoriesPage(context, {super.key});

  @override
  State<CurrentDayMemoriesPage> createState() => _CurrentDayMemoriesPageState();
}

class _CurrentDayMemoriesPageState extends State<CurrentDayMemoriesPage> {
  late Future<CalendarDayD> currentDay;
  String? _lastRequestedDay;

  /// Загружает памяти на выбранный день. Dneslov считает по старому стилю —
  /// отсюда тринадцать дней.
  ///
  /// Один вход на все смены дня: запоминает, что запрошено, — иначе «Повторить»
  /// спрашивал бы прежний день, а didChangeDependencies слал бы второй такой же
  /// запрос следом.
  void _loadFor(DateTime date) {
    final day = _dneslovDay(date);
    _lastRequestedDay = day;
    currentDay = getCalendarDayD(day);
  }

  /// День по старому стилю, как его спрашивает dneslov.org.
  static String _dneslovDay(DateTime date) =>
      DateFormat('dd.MM.yyyy').format(date.subtract(const Duration(days: 13)));

  void _retry() {
    final day = _lastRequestedDay;
    if (day == null) return;
    setState(() {
      currentDay = getCalendarDayD(day);
    });
  }

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
    final date = StoreProvider.of<AppState>(context).state.common.date;
    // Метод зовётся и тогда, когда день прежний (см. main_page): не перегружаем.
    final valFormat = _dneslovDay(date);
    if (valFormat == _lastRequestedDay) return;
    _loadFor(date);
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
    if (!context.mounted) return;
    if (picked != null && picked != StoreProvider.of<AppState>(context).state.common.date) {
      StoreProvider.of<AppState>(context).dispatch(
          ChangeCommonDateAction(picked)
      );
      setState(() => _loadFor(picked));
    }
  }

  void _showSelectDate(BuildContext context) {
    return buildMaterialDatePicker(context);
  }

  void onOpenEventDneslov(CalendarDayDItem item, String calendarString) {
    final date = _dneslovDay(StoreProvider.of<AppState>(context).state.common.date);
    Uri myUrl = Uri.parse("https://dneslov.org/${item.slug}/${item.eventId}?c=$calendarString&d=ю$date");
    launchUrl(myUrl);
  }

  @override
  Widget build(BuildContext context) {
    DateFormat format = DateFormat("dd.MM.yyyy");
    // String value = _selectedDate.isRegistered ? format.format(_selectedDate.value) : "Не задано";
    String value =
        format.format(StoreProvider.of<AppState>(context).state.common.date);
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
        color: Theme.of(context).scaffoldBackgroundColor,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<CalendarDayD>(
              future: currentDay,
              builder: (context, future) {
                // И состояние, а не одно `hasData`: при смене будущего
                // FutureBuilder держит прежние данные — под новой датой стоял
                // бы вчерашний день.
                if (future.connectionState == ConnectionState.done && future.hasData) {
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
                } else if (future.connectionState == ConnectionState.done && future.hasError) {
                  return ApiErrorView(
                    error: future.error,
                    message: "Не удалось загрузить памяти дня.",
                    hint: "Памяти приходят со стороннего сайта dneslov.org — иногда он недоступен.",
                    onRetry: _retry,
                  );
                }
                return Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
          ),
      ),
    );
  }
}