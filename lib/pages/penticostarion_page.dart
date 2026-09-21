import 'package:flutter/material.dart';

import 'package:typikon/components/api_error_view.dart';

import 'package:typikon/apiMapper/collections.dart';
import 'package:typikon/dto/penticostarion.dart';
import "package:typikon/dto/week.dart";
import 'package:typikon/components/week_tile.dart';

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

  /// Повторная попытка после отказа. Прежде на её месте стоял текст
  /// исключения: прочесть его нечем, а повторить — нечем тем более.
  void _retry() {
    setState(() {
      penticostarion = getPenticostarion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Период Цветной Триоди", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                  // Дни грузятся по раскрытии: перечень их больше не несёт.
                  return WeekTile(week: item, title: getTitle(item.value, item.type));
                },
              );
            } else if (future.hasError) {
              return ApiErrorView(
                error: future.error,
                message: "Не удалось загрузить Цветную Триодь.",
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