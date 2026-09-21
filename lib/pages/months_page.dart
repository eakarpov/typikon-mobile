import 'package:flutter/material.dart';

import 'package:typikon/components/async_view.dart';
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
  Future<void> _refresh() {
    _retry();
    return settle(months);
  }

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
        child: AsyncView<MonthList>(
          future: months,
          message: "Не удалось загрузить список месяцев.",
          onRetry: _retry,
          onRefresh: _refresh,
          isEmpty: (data) => data.list.isEmpty,
          emptyMessage: "Список месяцев пуст.",
          builder: (context, data) {
            final list = data.list;
            return ListView.builder(
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
          },
        ),
      ),
    );
  }
}