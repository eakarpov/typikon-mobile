import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter/gestures.dart';

import 'package:typikon/apiMapper/days.dart';
import 'package:typikon/dto/day.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/utils/bible_route.dart';
import 'package:typikon/utils/text.dart';
import 'package:typikon/components/table_of_contents.dart';
import 'package:typikon/components/verse_list.dart';

class DaysPage extends StatefulWidget {
  final String id;

  const DaysPage(context, {super.key, required this.id});

  @override
  State<DaysPage> createState() => _DaysPageState();
}

class _Section {
  final String title;

  /// Только те пункты, которые есть что показать: у слота бывают заготовки без
  /// текста и без зачала, и рисовать их пустым заголовком незачем.
  final List<DayTextsPart> items;

  _Section(this.title, DayTextsParts? part)
      : items = (part?.items ?? const <DayTextsPart>[])
            .where((item) => item.isPericope || item.text != null)
            .toList();

  bool get isEmpty => items.isEmpty;
}

class _DaysPageState extends State<DaysPage> {
  late Future<DayTexts> day;

  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    day = getDay(widget.id);
  }

  GlobalKey _sectionKey(String title) => _sectionKeys.putIfAbsent(title, () => GlobalKey());
  GlobalKey _itemKey(String id) => _itemKeys.putIfAbsent(id, () => GlobalKey());

  /// Места службы в том же порядке и составе, что и на странице чтений дня
  /// наряду. Раньше здесь не было ни Евангелия, ни Апостола, ни паремий, и
  /// седмичные дни (например, недели по Пятидесятнице) выглядели пустыми,
  /// хотя чтения на них у сервера есть.
  List<_Section> _sections(DayTexts data) {
    return [
      _Section("На паремиях вечерни по прокимне", data.vespersProkimenon),
      _Section("На всенощном бдении перед шестопсалмием", data.vigil),
      _Section("По седальнах первой кафизмы", data.kathisma1),
      _Section("По седальнах второй кафизмы", data.kathisma2),
      _Section("По седальнах третьей кафизмы", data.kathisma3),
      _Section("После Евангелия перед 50-м псалмом", data.before50),
      _Section("По ипакои", data.ipakoi),
      _Section("По седальнах полиелея", data.polyeleos),
      _Section("Евангелие на утрени", data.gospelMatins),
      _Section("По седальнах третьей песни", data.song3),
      _Section("По кондаке и икосе шестой песни", data.song6),
      _Section("По отпустительным тропарям", data.apolutikaTroparia),
      _Section("Перед первым часом", data.before1h),
      _Section("На первом часе", data.h1),
      _Section("На 3-м часе", data.h3),
      _Section("На 6-м часе", data.h6),
      _Section("На 9-м часе", data.h9),
      _Section("Апостол на Литургии", data.apostleLiturgy),
      _Section("Евангелие на Литургии", data.gospelLiturgy),
      _Section("На панагии", data.panagia),
    ].where((s) => !s.isEmpty).toList();
  }

  /// Как называется пункт: у зачала своего имени нет, есть ссылка ("Мк. 13").
  String _itemTitle(DayTextsPart item) =>
      item.pericope?.label.isNotEmpty == true
          ? item.pericope!.label
          : (item.description.isNotEmpty ? item.description : (item.text?.name ?? "Без названия"));

  /// Ключ якоря включает место службы: один и тот же текст (или зачало) может
  /// стоять сразу в нескольких местах дня, а два одинаковых GlobalKey в дереве
  /// — это исключение, а не просто неудобство.
  String _itemAnchor(DayTextsPart item, String sectionTitle) =>
      "$sectionTitle::${item.text?.id ?? item.pericope?.id ?? _itemTitle(item)}";

  List<TocEntry> _toc(List<_Section> sections) {
    return sections.map((s) => TocEntry(
      title: s.title,
      anchorKey: _sectionKey(s.title),
      children: s.items.map((item) => TocEntry(
        title: _itemTitle(item),
        anchorKey: _itemKey(_itemAnchor(item, s.title)),
      )).toList(),
    )).toList();
  }

  String getContent (DayTextsPart item) {
    var statia = item.statia != null ? (item.statia! - 1) : 0;
    var parts = getStatias(item.text!.content);
    return parts[statia];
  }

  void _openTextSheet(BuildContext context, DayText text) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 125,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, "/reading", arguments: text.id);
                  },
                  child: Text("Перейти к тексту",
                    style: TextStyle(
                      fontFamily: "OldStandard",
                      color: Colors.blue,
                    ),
                  ),
                ),
                Container(
                  height: 15,
                ),
                GestureDetector(
                  onTap: () {
                    if (text.book?.id != null)  {
                      Navigator.pushNamed(context, "/library", arguments: text.book!.id);
                    }
                  },
                  child: Text("Перейти к книге",
                    style: TextStyle(
                      fontFamily: "OldStandard",
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget renderItem(BuildContext context, _Section section) {
    var textStyle = TextStyle(
      fontFamily: "OldStandard",
      fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble(),
      color: StoreProvider.of<AppState>(context).state.settings.fontColor,
    );
    var textCsStyle = TextStyle(
      fontFamily: "Monomakh",
      fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble(),
      color: StoreProvider.of<AppState>(context).state.settings.fontColor,
    );
    const titleStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      color:  Colors.red,
    );
    final fontSize = StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble();
    return Column(
      key: _sectionKey(section.title),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title, style: titleStyle),
        ...section.items.map((item) => Column(
          key: _itemKey(_itemAnchor(item, section.title)),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: item.text == null ? null : () => _openTextSheet(context, item.text!),
              child: Text(_itemTitle(item), style: titleStyle),
            ),
            if (item.isPericope) ...[
              if (item.pericope!.verses.isNotEmpty)
                VerseListView(
                  verses: item.pericope!.verses,
                  fontSize: fontSize,
                  fontFamily: "Monomakh",
                )
              else
                Text(
                  "Текст для этого языка Библии ещё не размечен.",
                  style: TextStyle(fontFamily: "OldStandard", fontSize: fontSize, fontStyle: FontStyle.italic),
                ),
              // Кнопка показывается только когда есть куда вести: без книги
              // или без границ она уводила бы в ошибку, а дневные ответы лежат
              // в кэше сутками — то есть поломка пережила бы выпуск.
              if (item.pericope!.bookSlug != null && item.pericope!.ranges.isNotEmpty) Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    "/bible",
                    arguments: bibleRouteArgument(
                      item.pericope!.bookSlug!,
                      chapter: item.pericope!.ranges.first.chapterFrom,
                      ranges: item.pericope!.ranges,
                    ),
                  ),
                  child: const Text("Читать целиком →"),
                ),
              ),
            ] else if (item.text != null)
              Text(
                getContent(item),
                textAlign: TextAlign.justify,
                style: item.text!.csSource ? textCsStyle : textStyle,
              ),
          ],
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // DateFormat format = DateFormat("dd.MM.yyyy");
    // String value = _selectedDate.isRegistered ? format.format(_selectedDate.value) : "Не задано";
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DayTexts>(
            future: day,
            builder: (context, future) {
              if (future.hasData) {
                return Text("Чтение на день: ${future.data!.name}", style: TextStyle(fontFamily: "OldStandard"));
              }
              return Text("");
            },
        ),
        actions: <Widget>[
          FutureBuilder<DayTexts>(
            future: day,
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
        ],
      ),
      body: Container(
        color: StoreProvider.of<AppState>(context).state.settings.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<DayTexts>(
          future: day,
          builder: (context, future) {
            if (future.hasData) {
              final sections = _sections(future.data!);
              List<Widget> children = sections
                  .map((section) => renderItem(context, section))
                  .expand((element) => [element, Image.asset("assets/images/divider.png") ]).toList();
              if (children.isNotEmpty) {
                children.removeLast();
              }
              children.add(Image.asset("assets/images/end-ornament.png"));

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: children,
                  ),
                ),
              );
            }
            if (future.hasError) {
              return Text("Ошибка: ${future.error}");
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
