import 'package:flutter/material.dart';

import 'package:typikon/components/async_view.dart';
import 'package:intl/intl.dart';
import 'package:typikon/apiMapper/months.dart';
import 'package:typikon/dto/month.dart';

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
  Future<void> _refresh() {
    _retry();
    return settle(month);
  }

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
        child: AsyncView<MonthWithDays>(
          future: month,
          message: "Не удалось загрузить месяц.",
          onRetry: _retry,
          onRefresh: _refresh,
          isEmpty: (data) => data.days.isEmpty,
          emptyMessage: "В этом месяце нет дней с чтениями.",
          builder: (context, data) => ListView.builder(
            itemCount: data.days.length,
            itemBuilder: (context, index) {
              final item = data.days[index];
              return ListTile(
                title: Text(item.name ?? ""),
                // Псевдонимом: вторая версия API спрашивает день по нему.
                onTap: () => Navigator.pushNamed(context, "/days",
                    arguments: item.alias ?? item.id),
              );
            },
          ),
        ),
      ),
    );
  }
}