import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:typikon/apiMapper/saints.dart';
import "package:typikon/dto/saint.dart";
import "package:typikon/dto/text.dart";

class SaintPage extends StatefulWidget {
  final String id;

  const SaintPage(context, {super.key, required this.id});

  @override
  State<SaintPage> createState() => _SaintPageState();
}

class _SaintPageState extends State<SaintPage> {
  late Future<Saint> saint;

  @override
  void initState() {
    super.initState();
    saint = getSaint(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 3,
        child: Scaffold(
        appBar: AppBar(
          title: FutureBuilder<Saint>(
            future: saint,
            builder: (context, future) {
              if (future.hasData) {
                String name = future.data!.id??"";
                return Text(name);
              } else if (future.hasError) {
                return Text('${future.error}');
              }
              return const CircularProgressIndicator();
            },
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Тексты"),
              Tab(text: "Упоминания"),
              Tab(text: "Авторство"),
            ],
          ),
        ),
        body: Container(
          color: const Color(0xffffffff),
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: FutureBuilder<Saint>(
            future: saint,
            builder: (context, future) {
              if (future.hasData) {
                List<Reading> texts = future.data!.texts;
                List<Reading> mentions = future.data!.mentions;
                return TabBarView(
                  children: [
                    ListView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: texts.length,
                      itemBuilder: (context, index) {
                        final item = texts[index];
                        return Container(
                          child: ListTile(
                            title: Text(item.name??"", style: TextStyle(fontFamily: "OldStandard")),
                            onTap: () => {
                              Navigator.pushNamed(context, "/days", arguments: item.id)
                            },
                          ),
                        );
                      },
                    ),
                    ListView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: mentions.length,
                      itemBuilder: (context, index) {
                        final item = mentions[index];
                        return Container(
                          child: ListTile(
                            title: Text(item.name??"", style: TextStyle(fontFamily: "OldStandard")),
                            onTap: () => {
                              Navigator.pushNamed(context, "/days", arguments: item.id)
                            },
                          ),
                        );
                      },
                    ),
                    ListView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: 0,
                      itemBuilder: (context, index) {
                        return Container();
                      },
                    ),
                  ],
                );
              } else if (future.hasError) {
                return Text('${future.error}');
              }
              return Container(
                color: const Color(0xffffffff),
                width: double.infinity,
                height: double.infinity,
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
      ),
    );
  }
}