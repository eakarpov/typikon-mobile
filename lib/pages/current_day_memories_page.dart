import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:typikon/apiMapper/dneslov/calendar.dart';
import 'package:typikon/dto/dneslov/calendar.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/components/async_view.dart';
import 'package:typikon/utils/selected_day.dart';

class CurrentDayMemoriesPage extends StatefulWidget {
  const CurrentDayMemoriesPage(context, {super.key});

  @override
  State<CurrentDayMemoriesPage> createState() => _CurrentDayMemoriesPageState();
}

class _CurrentDayMemoriesPageState extends State<CurrentDayMemoriesPage>
    with WidgetsBindingObserver, SelectedDay {
  late Future<CalendarDayD> currentDay;

  /// Как эта страница грузит свой день; когда и по какому поводу — знает
  /// примесь SelectedDay.
  ///
  /// Dneslov считает по старому стилю — отсюда тринадцать дней.
  @override
  void loadDay(DateTime day) {
    currentDay = getCalendarDayD(_dneslovDay(day));
  }

  Future<void> _refresh() {
    reloadSelectedDay();
    return settle(currentDay);
  }

  /// День по старому стилю, как его спрашивает dneslov.org.
  static String _dneslovDay(DateTime date) =>
      DateFormat('dd.MM.yyyy').format(date.subtract(const Duration(days: 13)));


  void onOpenEventDneslov(CalendarDayDItem item, String calendarString) {
    final date = _dneslovDay(selectedDay);
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
              pickDay();
              // _restorableDatePickerRouteFuture.present();
            },
          )
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AsyncView<CalendarDayD>(
          future: currentDay,
          message: "Не удалось загрузить памяти дня.",
          hint: "Памяти приходят со стороннего сайта dneslov.org — иногда он недоступен.",
          onRetry: reloadSelectedDay,
          onRefresh: _refresh,
          isEmpty: (data) => data.list.isEmpty,
          emptyMessage: "На этот день памятей нет.",
          builder: (context, data) => ListView.builder(
            itemCount: data.list.length,
            itemBuilder: (context, index) {
              final item = data.list[index];
              return ListTile(
                onTap: () =>
                    Navigator.pushNamed(context, "/saints", arguments: item.slug),
                leading: Text(item.saintTitle ?? "св"),
                title: Text(item.title ?? ""),
                subtitle: Text(item.happenedAt ?? ""),
              );
            },
          ),
        ),
      ),
    );
  }
}