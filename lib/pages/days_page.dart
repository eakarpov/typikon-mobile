import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:typikon/apiMapper/days.dart';
import 'package:typikon/dto/day.dart';
import 'package:typikon/store/models/models.dart';

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
        color: const Color(0xffffffff),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<DayTexts>(
          future: day,
          builder: (context, future) {
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
                              Text(item.text!.name, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                item.text!.content,
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
                              Text(item.text!.name, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                item.text!.content,
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
                              Text(item.text!.name, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                item.text!.content,
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
                              Text(item.text!.name, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                item.text!.content,
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
                              Text(item.text!.name, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                item.text!.content,
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
                              Text(item.text!.name, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                item.text!.content,
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
                              Text(item.text!.name, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                item.text!.content,
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
                              Text(item.text!.name, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                item.text!.content,
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
                              Text(item.text!.name, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                item.text!.content,
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