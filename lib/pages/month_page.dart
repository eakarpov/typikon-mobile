import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:typikon/apiMapper/months.dart';
import 'package:typikon/dto/month.dart';
import "package:typikon/dto/day.dart";

class MonthPage extends StatefulWidget {
  final String id;

  const MonthPage(context, {super.key, required this.id});

  @override
  State<MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends State<MonthPage> {
  late Future<MonthWithDays> month;

  @override
  void initState() {
    super.initState();
    month = getMonth(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<MonthWithDays>(
          future: month,
          builder: (context, future) {
            if (future.hasData) {
              String locale = Localizations.localeOf(context).languageCode;
              DateTime now = DateTime.now();
              DateTime newDate =  DateTime.utc(now.year, future.data!.value ?? 0);
              String month = DateFormat.MMMM(locale).format(newDate);
              return Text(month);
            } else if (future.hasError) {
              return Text('${future.error}');
            }
            return const Text("");
          },
        ),
      ),
      body: Container(
        color: const Color(0xffffffff),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<MonthWithDays>(
          future: month,
          builder: (context, future) {
            if (future.hasData) {
              List<DayTexts> list = future.data!.days;
              return ListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Container(
                    child: ListTile(
                      title: Text(item.name??""),
                      onTap: () => {
                        Navigator.pushNamed(context, "/days", arguments: item.id)
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
    );
  }
}