import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:typikon/store/models/models.dart';
import 'package:typikon/apiMapper/calendar.dart';
import 'package:typikon/dto/calendar.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/components/table_of_contents.dart';
import 'package:typikon/components/verse_list.dart';
import 'package:typikon/components/day_memories.dart';
import 'package:typikon/components/trapeza_line.dart';
import 'package:typikon/utils/bible_route.dart';

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
    currentDay = getCalendarDay(DateFormat('yyyy-MM-dd').format(
        StoreProvider.of<AppState>(context, listen: false).state.common.date));
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

  /// Ключ якоря включает место службы: один и тот же текст может стоять сразу
  /// в нескольких местах дня, а два одинаковых GlobalKey в дереве — это
  /// исключение и пустой экран, а не просто неудобство (то же в days_page).
  String _itemAnchor(CalendarDayPartItem item, String sectionTitle) =>
      "$sectionTitle::${item.id ?? item.name}";

  List<TocEntry> _toc(List<_Section> sections) {
    return sections.map((s) => TocEntry(
      title: s.title,
      anchorKey: _sectionKey(s.title),
      children: s.part!.items!.map((item) => TocEntry(
        title: item.name,
        anchorKey: _itemKey(_itemAnchor(item, s.title)),
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
          key: _itemKey(_itemAnchor(item, section.title)),
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
            if (item.isPericope && item.bookSlug != null && item.ranges.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    "/bible",
                    arguments: bibleRouteArgument(
                      item.bookSlug!,
                      chapter: item.ranges.first.chapterFrom,
                      ranges: item.ranges,
                    ),
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
    String value =
        format.format(StoreProvider.of<AppState>(context).state.common.date);
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
            tooltip: "Выбрать дату",
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
            // И состояние, а не одно `hasData`: при смене будущего FutureBuilder
            // держит прежние данные — под новой датой стоял бы вчерашний день.
            if (future.connectionState == ConnectionState.done && future.hasData) {
              final sections = _sections(future.data!);
              return SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Своим запросом: служба устава отвечает до восьми
                        // секунд, и чтения ждать её не должны.
                        TrapezaLine(
                          date: StoreProvider.of<AppState>(context).state.common.date,
                        ),
                        DayMemoriesView(memories: future.data!.memories),
                        ...sections.map((section) => renderItem(context, section)),
                      ],
                    ),
                ),
              );
            } else if (future.connectionState == ConnectionState.done && future.hasError) {
              return Center(child: Text('Для этой даты формирование выдачи недоступно'));
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
