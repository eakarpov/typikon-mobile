import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:typikon/apiMapper/collections.dart';
import 'package:typikon/dto/penticostarion.dart';
import "package:typikon/dto/week.dart";

String getTitle(int? value, String? type) {
  if (value is int && type is String) {
    return "Неделя $value по ${type == "Pascha" ? "Пасхе" : "Пятидесятнице"}";
  }
  return "";
}


class PenticostarionPage extends StatefulWidget {
  const PenticostarionPage(context, {super.key});

  @override
  State<PenticostarionPage> createState() => _PenticostarionPageState();
}

class _PenticostarionPageState extends State<PenticostarionPage> {
  late Future<PenticostarionCollection> penticostarion;

  @override
  void initState() {
    super.initState();
    penticostarion = getPenticostarion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Период Цветной Триоди"),
      ),
      body: Container(
        color: const Color(0xffffffff),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<PenticostarionCollection>(
          future: penticostarion,
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
                      title: Text(getTitle(item.value, item.type)),
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