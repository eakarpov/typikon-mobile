import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:typikon/apiMapper/library.dart';
import 'package:typikon/dto/library.dart';

import '../apiMapper/months.dart';
import '../dto/month.dart';

class MonthsPage extends StatefulWidget {
  const MonthsPage(context, {super.key});

  @override
  State<MonthsPage> createState() => _MonthsPageState();
}

class _MonthsPageState extends State<MonthsPage> {
  late Future<MonthList> months;

  @override
  void initState() {
    super.initState();
    months = getMonths();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Выберите месяц", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: const Color(0xffffffff),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<MonthList>(
          future: months,
          builder: (context, future) {
            if (future.hasData) {
              List<Month> list = future.data!.list;
              return ListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  String locale = Localizations.localeOf(context).languageCode;
                  DateTime now = DateTime.now();
                  DateTime newDate =  DateTime.utc(now.year, item.value ?? 0);
                  String month = DateFormat.MMMM(locale).format(newDate);
                  return Container(
                    child: ListTile(
                      title: Text(month),
                      onTap: () => {
                        Navigator.pushNamed(context, "/months", arguments: item.id)
                      },
                    ),
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