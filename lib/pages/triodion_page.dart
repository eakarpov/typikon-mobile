import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:typikon/apiMapper/collections.dart';
import 'package:typikon/dto/triodion.dart';
import "package:typikon/dto/week.dart";

String getTitle(int? value, String? type, String? label) {
  if (value is int && type is String) {
    return "${type == "Fast" ? "Неделя $value Великого поста" : label}";
  }
  return "";
}

class TriodionPage extends StatefulWidget {
  const TriodionPage(context, {super.key});

  @override
  State<TriodionPage> createState() => _TriodionPageState();
}

class _TriodionPageState extends State<TriodionPage> {
  late Future<TriodionCollection> triodion;

  @override
  void initState() {
    super.initState();
    triodion = getTriodion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Период Постной Триоди"),
      ),
      body: Container(
        color: const Color(0xffffffff),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<TriodionCollection>(
          future: triodion,
          builder: (context, future) {
            if (future.hasData) {
              List<WeekWithDays> list = future.data!.weeks;
              return ListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Container(
                      child: ExpansionTile(
                        title: Text(getTitle(item.value, item.type, item.label)),
                        children: item.days!.map<Widget>((day) =>
                            ListTile(
                              title: Text(day.name??"test"),
                              onTap: () => {
                                Navigator.pushNamed(context, "/days", arguments: day.id)
                              },
                            )
                        ).toList(),
                      )
                  );
                },
              );
            } else if (future.hasError) {
              return Text('${future.error}');
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