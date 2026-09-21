import 'package:flutter/material.dart';

import 'package:typikon/components/async_view.dart';

import 'package:typikon/apiMapper/collections.dart';
import 'package:typikon/dto/triodion.dart';
import 'package:typikon/components/week_tile.dart';

String getTitle(int? value, String? type, String? label) {
  if (value is int && type is String) {
    return label != null ? label : "${type == "Fast" ? "Неделя $value Великого поста" : ""}";
  }
  return "";
}

class TriodionPage extends StatefulWidget {
  const TriodionPage(context, {super.key});

  @override
  State<TriodionPage> createState() => _TriodionPageState();
}

class _TriodionPageState extends State<TriodionPage> {
  late Future<TriodionCollection> triodion;

  @override
  void initState() {
    super.initState();
    triodion = getTriodion();
  }

  /// Повторная попытка после отказа. Прежде на её месте стоял текст
  /// исключения: прочесть его нечем, а повторить — нечем тем более.
  Future<void> _refresh() {
    _retry();
    return settle(triodion);
  }

  void _retry() {
    setState(() {
      triodion = getTriodion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Период Постной Триоди", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AsyncView<TriodionCollection>(
          future: triodion,
          message: "Не удалось загрузить Постную Триодь.",
          onRetry: _retry,
          onRefresh: _refresh,
          isEmpty: (data) => data.weeks.isEmpty,
          emptyMessage: "Седмиц в этом периоде нет.",
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