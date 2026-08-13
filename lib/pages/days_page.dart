import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter/gestures.dart';

import 'package:typikon/apiMapper/days.dart';
import 'package:typikon/dto/day.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/utils/text.dart';
import 'package:typikon/components/table_of_contents.dart';

class DaysPage extends StatefulWidget {
  final String id;

  const DaysPage(context, {super.key, required this.id});

  @override
  State<DaysPage> createState() => _DaysPageState();
}

class _Section {
  final String title;
  final DayTextsParts? part;

  _Section(this.title, this.part);
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

  List<_Section> _sections(DayTexts data) {
    return [
      _Section("По седальнах первой кафизмы", data.kathisma1),
      _Section("По седальнах второй кафизмы", data.kathisma2),
      _Section("По седальнах третьей кафизмы", data.kathisma3),
      _Section("После Евангелия перед 50-м псалмом", data.before50),
      _Section("По ипакои", data.ipakoi),
      _Section("По седальнах полиелея", data.polyeleos),
      _Section("По седальнах третьей песни", data.song3),
      _Section("По кондаке и икосе шестой песни", data.song6),
      _Section("По отпустительным тропарям", data.apolutikaTroparia),
      _Section("Перед первым часом", data.before1h),
      _Section("На 3-м часе", data.h3),
      _Section("На 6-м часе", data.h6),
      _Section("На 9-м часе", data.h9),
    ].where((s) => s.part?.items?.isNotEmpty == true).toList();
  }

  List<TocEntry> _toc(List<_Section> sections) {
    return sections.map((s) => TocEntry(
      title: s.title,
      anchorKey: _sectionKey(s.title),
      children: s.part!.items!.map((item) => TocEntry(
        title: item.text?.name ?? "Без названия",
        anchorKey: _itemKey(item.text?.id ?? item.text?.name ?? s.title),
      )).toList(),
    )).toList();
  }

  String getContent (DayTextsPart item) {
    var statia = item.statia != null ? (item.statia! - 1) : 0;
    var parts = getStatias(item.text!.content);
    return parts[statia];
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
    return Column(
          key: _sectionKey(section.title),
          children: [
            Text(section.title, style: titleStyle),
            ...section.part!.items!.map((item) => Column(
              key: _itemKey(item.text?.id ?? item.text?.name ?? section.title),
              children: [
                GestureDetector(
                  onTap: () {
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
                                    if (item.text!.id != null) {
                                      Navigator.pushNamed(context, "/reading", arguments: item.text!.id);
                                    }
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
                                    if (item.text!.book?.id != null)  {
                                      Navigator.pushNamed(context, "/library", arguments: item.text!.book!.id);
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
                  },
                  child: Text(
                    item.text!.name,
                    style: titleStyle,
                  ),
                ),
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
