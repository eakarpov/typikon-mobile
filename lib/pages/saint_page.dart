import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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

  void onOpenLinks(BuildContext context, List<DneslovLink> links) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          child: Padding(
            padding: EdgeInsets.fromLTRB(5.0, 10.0, 5.0, 10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: links.map((link) => Padding(
                padding: EdgeInsets.all(5.0),
                child: InkWell(
                    child: Text(link.url, style: TextStyle(color: Colors.blue)),
                    onTap: () => launch(link.url)
                ),
              )).toList(),
            ),
          ),
        );
      },
    );
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
                DneslovMemo? memo = future.data!.memory!.memoes.length > 0
                    ? future.data!.memory!.memoes.first
                    : null;
                return Text(memo != null ? memo.title : "", style: TextStyle(fontFamily: 'OldStandard'));
              } else if (future.hasError) {
                return Text('${future.error}');
              }
              return const CircularProgressIndicator();
            },
          ),
          actions: <Widget>[
            FutureBuilder<Saint>(
              future: saint,
              builder: (context, future) {
                if (future.hasData) {
                  List<DneslovLink> links = future.data!.memory!.links;
                  if (!links.isEmpty) {
                    return IconButton(
                        onPressed: () => onOpenLinks(context, links),
                        icon: Icon(
                          Icons.link,
                          color: Colors.white,
                        )
                    );
                  }
                  return Container();
                } else if (future.hasError) {
                  return Container();
                }
                return Container();
              },
            ),
            FutureBuilder<Saint>(
              future: saint,
              builder: (context, future) {
                if (future.hasData) {
                  String? slug = future.data!.slug;
                  if (slug != null) {
                    return IconButton(
                        onPressed: () => launchUrl(
                          Uri.parse("https://dneslov.org/${slug}?c=днес,рпц")
                        ),
                        icon: Icon(
                          Icons.outbond_outlined,
                          color: Colors.white,
                        )
                    );
                  }
                  return Container();
                } else if (future.hasError) {
                  return Container();
                }
                return Container();
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: "Житие"),
              Tab(text: "Тексты"),
              Tab(text: "Упоминания"),
              // Tab(text: "Авторство"),
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
                DneslovMemo? memo = future.data!.memory!.memoes.length > 0
                    ? future.data!.memory!.memoes.first
                    : null;
                return TabBarView(
                      children: [
                        Markdown(data: memo != null ? memo.description : ""),
                        ListView.builder(
                          scrollDirection: Axis.vertical,
                          itemCount: texts.length,
                          itemBuilder: (context, index) {
                            final item = texts[index];
                            return Container(
                              child: ListTile(
                                title: Text(item.name??"", style: TextStyle(fontFamily: "OldStandard")),
                                onTap: () => {
                                  Navigator.pushNamed(context, "/reading", arguments: item.id)
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
                        // ListView.builder(
                        //   scrollDirection: Axis.vertical,
                        //   itemCount: 0,
                        //   itemBuilder: (context, index) {
                        //     return Container();
                        //   },
                        // ),
                      ],
                );
              } else if (future.hasError) {
                return Text('${future.error}');
              }
              return Container(
                color: const Color(0xffffffff),
                width: double.infinity,
                height: double.infinity,
                child: Align(
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}