import 'package:flutter/material.dart';

import 'package:typikon/components/api_error_view.dart';
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

  /// Повторная попытка после отказа. Прежде на её месте стоял текст
  /// исключения: прочесть его нечем, а повторить — нечем тем более.
  void _retry() {
    setState(() {
      month = getMonth(widget.id);
    });
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
              return Text(month, style: TextStyle(fontFamily: "OldStandard"));
            } else if (future.hasError) {
              // В заголовке — короткий ярлык, а не вид ошибки: целый экран
              // с «Повторить» показывается ниже, в теле страницы.
              return const Text("Месяц", style: TextStyle(fontFamily: "OldStandard"));
            }
            return const Text("");
          },
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                        // Псевдонимом: вторая версия API спрашивает день по нему.
                        Navigator.pushNamed(context, "/days", arguments: item.alias ?? item.id)
                      },
                    ),
                  );
                },
              );
            } else if (future.hasError) {
              return ApiErrorView(
                error: future.error,
                message: "Не удалось загрузить месяц.",
                onRetry: _retry,
              );
            }
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: double.infinity,
              height: double.infinity,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }
}