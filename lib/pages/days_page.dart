import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter/gestures.dart';

import 'package:typikon/apiMapper/days.dart';
import 'package:typikon/dto/day.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/utils/text.dart';

class DaysPage extends StatefulWidget {
  final String id;

  const DaysPage(context, {super.key, required this.id});

  @override
  State<DaysPage> createState() => _DaysPageState();
}

class _DaysPageState extends State<DaysPage> {
  late Future<DayTexts> day;

  @override
  void initState() {
    super.initState();
    day = getDay(widget.id);
  }

  String getContent (DayTextsPart item) {
    var statia = item.statia != null ? (item.statia! - 1) : 0;
    var parts = getStatias(item.text!.content);
    return parts[statia];
  }

  Widget renderItem(BuildContext context, DayTextsParts part, String title) {
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
    return (
        Column(
          children: [
            Text(title, style: titleStyle),
            ...part.items!.map((item) => Column(
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
        )
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
      ),
      body: Container(
        color: StoreProvider.of<AppState>(context).state.settings.backgroundColor,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<DayTexts>(
          future: day,
          builder: (context, future) {
            if (future.hasData) {
              List<Widget> children = [
                if (future.data!.kathisma1 != null) renderItem(
                  context,
                  future.data!.kathisma1!,
                  "По седальнах первой кафизмы",
                ),
                if (future.data!.kathisma2 != null) renderItem(
                  context,
                  future.data!.kathisma2!,
                  "По седальнах второй кафизмы",
                ),
                if (future.data!.kathisma3 != null) renderItem(
                  context,
                  future.data!.kathisma3!,
                  "По седальнах третьей кафизмы",
                ),
                if (future.data!.before50 != null) renderItem(
                  context,
                  future.data!.before50!,
                  "После Евангелия перед 50-м псалмом",
                ),
                if (future.data!.ipakoi != null) renderItem(
                  context,
                  future.data!.ipakoi!,
                  "По ипакои",
                ),
                if (future.data!.polyeleos != null) renderItem(
                  context,
                  future.data!.polyeleos!,
                  "По седальнах полиелея",
                ),
                if (future.data!.song3 != null) renderItem(
                  context,
                  future.data!.song3!,
                  "По седальнах третьей песни",
                ),
                if (future.data!.song6 != null) renderItem(
                  context,
                  future.data!.song6!,
                  "По кондаке и икосе шестой песни",
                ),
                if (future.data!.apolutikaTroparia != null) renderItem(
                  context,
                  future.data!.apolutikaTroparia!,
                  "По отпустительным тропарям",
                ),
                if (future.data!.before1h != null) renderItem(
                  context,
                  future.data!.before1h!,
                  "Перед первым часом",
                ),
                if (future.data!.h3 != null) renderItem(
                  context,
                  future.data!.h3!,
                  "На 3-м часе",
                ),
                if (future.data!.h6 != null) renderItem(
                  context,
                  future.data!.h6!,
                  "На 6-м часе",
                ),
                if (future.data!.h9 != null) renderItem(
                  context,
                  future.data!.h9!,
                  "На 9-м часе",
                ),
              ].expand((element) => [element, Image.asset("assets/images/divider.png") ]).toList();
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