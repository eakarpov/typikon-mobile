import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:typikon/apiMapper/collections.dart';
import 'package:typikon/dto/triodion.dart';
import "package:typikon/dto/week.dart";
import 'package:typikon/components/week_tile.dart';

String getTitle(int? value, String? type, String? label) {
  if (value is int && type is String) {
    if (type == "first") {
      return "Неделя $value по Пятидесятнице";
    }
    if (type == "second") {
      return label ?? "Неделя $value по Крестовоздвижении";
    }
    if (type == "third") {
      return label ?? "Неделя $value по Богоявлении";
    }
    return "";
  }
  return "";
}


class OutsidePage extends StatefulWidget {
  const OutsidePage(context, {super.key});

  @override
  State<OutsidePage> createState() => _OutsidePageState();
}

class _OutsidePageState extends State<OutsidePage> {
  late Future<TriodionCollection> data;

  @override
  void initState() {
    super.initState();
    data = getOutTriodion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Период вне Триодного цикла", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<TriodionCollection>(
          future: data,
          builder: (context, future) {
            if (future.hasData) {
              List<WeekWithDays> list = future.data!.weeks;
              return ListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  // Дни грузятся по раскрытии: перечень их больше не несёт.
                  return WeekTile(week: item, title: getTitle(item.value, item.type, item.label));
                },
              );
            } else if (future.hasError) {
              return Text('${future.error}');
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