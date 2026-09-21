import 'package:flutter/material.dart';

import 'package:typikon/components/async_view.dart';

import 'package:typikon/apiMapper/collections.dart';
import 'package:typikon/dto/triodion.dart';
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

  /// Повторная попытка после отказа. Прежде на её месте стоял текст
  /// исключения: прочесть его нечем, а повторить — нечем тем более.
  Future<void> _refresh() {
    _retry();
    return settle(data);
  }

  void _retry() {
    setState(() {
      data = getOutTriodion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Период вне Триодного цикла", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AsyncView<TriodionCollection>(
          future: data,
          message: "Не удалось загрузить чтения вне Триоди.",
          onRetry: _retry,
          onRefresh: _refresh,
          isEmpty: (data) => data.weeks.isEmpty,
          emptyMessage: "Седмиц вне Триоди нет.",
          builder: (context, data) {
            final list = data.weeks;
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                  final item = list[index];
                  // Дни грузятся по раскрытии: перечень их больше не несёт.
                  return WeekTile(week: item, title: getTitle(item.value, item.type, item.label));
              },
            );
          },
        ),
      ),
    );
  }
}