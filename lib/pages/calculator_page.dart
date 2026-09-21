import 'package:flutter/material.dart';

import 'package:typikon/utils/reading_style.dart';
import 'package:intl/intl.dart';

import 'package:typikon/apiMapper/calendar.dart';
import 'package:typikon/dto/calendar.dart';
import 'package:typikon/components/async_view.dart';
import 'package:typikon/components/table_of_contents.dart';
import 'package:typikon/components/verse_list.dart';
import 'package:typikon/components/day_memories.dart';
import 'package:typikon/components/trapeza_line.dart';
import 'package:typikon/utils/bible_route.dart';
import 'package:typikon/utils/selected_day.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage(context, {super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _Section {
  final String title;
  final List<CalendarDayPartItem> items;

  _Section(this.title, this.items);
}

class _CalculatorPageState extends State<CalculatorPage>
    with WidgetsBindingObserver, SelectedDay {
  late Future<CalendarDay> currentDay;

  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _itemKeys = {};

  Future<void> _refresh() {
    reloadSelectedDay();
    return settle(currentDay);
  }

  /// Как калькулятор грузит свой день; когда — знает примесь SelectedDay.
  @override
  void loadDay(DateTime day) {
    currentDay = getCalendarDay(SelectedDay.keyOf(day));
  }

  GlobalKey _sectionKey(String title) => _sectionKeys.putIfAbsent(title, () => GlobalKey());
  GlobalKey _itemKey(String id) => _itemKeys.putIfAbsent(id, () => GlobalKey());

  /// Места службы — из того перечня, что прислал сервер.
  ///
  /// Здесь был свой список из двадцати мест, разобранный по отдельным полям
  /// ответа (`data.vigil`, `data.kathisma1` и так далее). Вторая версия API
  /// таких полей не отдаёт вовсе — она присылает `readings`, перечень разделов
  /// с их же подписями, — и калькулятор показывал пустую страницу на любой
  /// день. Главная и страница дня переехали на `readings` ещё при переводе на
  /// v2, а это место тогда пропустили: поля были на месте, пока сервер их
  /// присылал, и поломка вышла наружу только с выкладкой.
  ///
  /// Подписи теперь тоже сервера: держать свои — значит однажды подписать
  /// раздел не так, как он называется на сайте.
  List<_Section> _sections(CalendarDay data) => data.readings
      .map((section) => _Section(section.title, section.items))
      .where((section) => section.items.isNotEmpty)
      .toList();

  /// Ключ якоря включает место службы: один и тот же текст может стоять сразу
  /// в нескольких местах дня, а два одинаковых GlobalKey в дереве — это
  /// исключение и пустой экран, а не просто неудобство (то же в days_page).
  String _itemAnchor(CalendarDayPartItem item, String sectionTitle) =>
      "$sectionTitle::${item.id ?? item.name}";

  List<TocEntry> _toc(List<_Section> sections) {
    return sections.map((s) => TocEntry(
      title: s.title,
      anchorKey: _sectionKey(s.title),
      children: s.items.map((item) => TocEntry(
        title: item.name,
        anchorKey: _itemKey(_itemAnchor(item, s.title)),
      )).toList(),
    )).toList();
  }

  Widget renderItem(BuildContext context, _Section section) {
    final list = section.items;
    var titleStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.red,
    );
    final fontSize = readingFontSize(context);
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
              const ReadingText(
                "Текст для этого языка Библии ещё не размечен.",
                italic: true,
              )
            else
              // Прежде калькулятор не брал ни цвета, ни выключки, ни интервала.
              ReadingText(item.content),
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
    String value = format.format(selectedDay);
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
            onPressed: pickDay,
          )
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AsyncView<CalendarDay>(
          future: currentDay,
          // Прежде здесь на всякий отказ стояло «Для этой даты формирование
          // выдачи недоступно» — в том числе когда просто не было сети.
          message: "Не удалось составить чтения на этот день.",
          onRetry: reloadSelectedDay,
          onRefresh: _refresh,
          builder: (context, data) {
            final sections = _sections(data);
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Своим запросом: служба устава отвечает до восьми
                    // секунд, и чтения ждать её не должны.
                    TrapezaLine(date: selectedDay),
                    DayMemoriesView(memories: data.memories),
                    ...sections.map((section) => renderItem(context, section)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
