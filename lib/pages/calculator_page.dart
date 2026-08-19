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
import 'package:typikon/components/table_of_contents.dart';
import 'package:typikon/components/verse_list.dart';
import 'package:typikon/components/day_memories.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage(context, {super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _Section {
  final String title;
  final CalendarDayPart? part;

  _Section(this.title, this.part);
}

class _CalculatorPageState extends State<CalculatorPage> {
  late Future<CalendarDay> currentDay;

  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _itemKeys = {};

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
      setState(() {
        currentDay = getCalendarDay(
            DateFormat('yyyy-MM-dd').format(
                picked
                    // .subtract(const Duration(days: 13))
            )
        );
      });
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
      setState(() {
        currentDay = getCalendarDay(
            DateFormat('yyyy-MM-dd').format(
                newSelectedDate
                    // .subtract(const Duration(days: 13))
            )
        );
      });
    }
  }

  GlobalKey _sectionKey(String title) => _sectionKeys.putIfAbsent(title, () => GlobalKey());
  GlobalKey _itemKey(String id) => _itemKeys.putIfAbsent(id, () => GlobalKey());

  List<_Section> _sections(CalendarDay data) {
    return [
      _Section("На паремиях вечерни по прокимне", data.vespersProkimenon),
      _Section("На всенощном бдении перед шестопсалмием", data.vigil),
      _Section("По седальнах первой кафизмы", data.kathisma1),
      _Section("По седальнах второй кафизмы", data.kathisma2),
      _Section("По седальнах третьей кафизмы", data.kathisma3),
      _Section("Перед 50-м псалмом после Евангелия", data.before50),
      _Section("По ипакои", data.ipakoi),
      _Section("По седальнах полиелея", data.polyeleos),
      _Section("Евангелие на утрени", data.gospelMatins),
      _Section("По седальнах третьей песни", data.song3),
      _Section("По кондаке и икосе по шестой песни", data.song6),
      _Section("По  отпустительным тропарям", data.apolutikaTroparia),
      _Section("Перед первым часом", data.before1h),
      _Section("На первом часе", data.h1),
      _Section("На 3-м часе", data.h3),
      _Section("На 6-м часе", data.h6),
      _Section("На 9-м часе", data.h9),
      _Section("Апостол на Литургии", data.apostleLiturgy),
      _Section("Евангелие на Литургии", data.gospelLiturgy),
      _Section("На панагии", data.panagia),
    ].where((s) => s.part?.items?.isNotEmpty == true).toList();
  }

  List<TocEntry> _toc(List<_Section> sections) {
    return sections.map((s) => TocEntry(
      title: s.title,
      anchorKey: _sectionKey(s.title),
      children: s.part!.items!.map((item) => TocEntry(
        title: item.name,
        anchorKey: _itemKey(item.id ?? item.name),
      )).toList(),
    )).toList();
  }

  Widget renderItem(BuildContext context, _Section section) {
    List<CalendarDayPartItem> list = section.part?.items ?? [];
    var titleStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.red,
    );
    final fontSize = StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble();
    return Column(
      key: _sectionKey(section.title),
      children: [
        Text(section.title, style: titleStyle),
        ...list.map((item) => Column(
          key: _itemKey(item.id ?? item.name),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: titleStyle),
            if (item.verses != null && item.verses!.isNotEmpty)
              VerseListView(
                verses: item.verses!,
                fontSize: fontSize,
                fontFamily: "Monomakh",
              )
            else if (item.isPericope)
              Text(
                "Текст для этого языка Библии ещё не размечен.",
                style: TextStyle(fontFamily: "OldStandard", fontSize: fontSize, fontStyle: FontStyle.italic),
              )
            else
              Text(
                item.content,
                textAlign: TextAlign.justify,
                style: TextStyle(fontFamily: "OldStandard", fontSize: fontSize),
              ),
            if (item.isPericope && item.id != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    "/reading",
                    arguments: item.verses != null && item.verses!.isNotEmpty
                        ? "${item.id}#${item.verses!.first.chapter}"
                        : item.id,
                  ),
                  child: const Text("Читать целиком →"),
                ),
              ),
          ],
        )),
      ],
    );
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
          FutureBuilder<CalendarDay>(
            future: currentDay,
            builder: (context, future) {
              if (!future.hasData) return SizedBox.shrink();
              final sections = _sections(future.data!);
              if (sections.isEmpty) return SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.toc, color: Colors.white),
                tooltip: "Оглавление",
                onPressed: () => showTableOfContents(context, _toc(sections)),
              );
            },
          ),
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
        child: FutureBuilder<CalendarDay>(
          future: currentDay,
          builder: (context, future) {
            if (future.hasData) {
              final sections = _sections(future.data!);
              return SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DayMemoriesView(memories: future.data!.memories),
                        ...sections.map((section) => renderItem(context, section)),
                      ],
                    ),
                ),
              );
            } else if (future.hasError) {
              return Center(child: Text('Для этой даты формирование выдачи недоступно'));
            }
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor,
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
