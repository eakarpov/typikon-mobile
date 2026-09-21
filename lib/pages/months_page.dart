import 'package:flutter/material.dart';

import 'package:typikon/components/api_error_view.dart';
import 'package:intl/intl.dart';

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

  /// Повторная попытка после отказа. Прежде на её месте стоял текст
  /// исключения: прочесть его нечем, а повторить — нечем тем более.
  void _retry() {
    setState(() {
      months = getMonths();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Выберите месяц", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                        // Псевдонимом, а не идентификатором: вторая версия API
                        // спрашивает месяц по нему, и он же стоит в адресах
                        // страниц сайта.
                        Navigator.pushNamed(context, "/months", arguments: item.alias ?? item.id)
                      },
                    ),
                  );
                },
              );
            } else if (future.hasError) {
              return ApiErrorView(
                error: future.error,
                message: "Не удалось загрузить список месяцев.",
                onRetry: _retry,
              );
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