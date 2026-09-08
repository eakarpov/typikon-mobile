import 'package:flutter/material.dart';

import '../apiMapper/collections.dart';
import '../dto/day.dart';
import '../dto/week.dart';

/// Седмица в перечне: заголовок, а дни — по раскрытии.
///
/// **Дни грузятся, когда их открывают, а не заранее.** Первая версия API
/// вкладывала дни прямо в перечень седмиц, и вместе с ними — все их тексты:
/// пятьдесят три седмицы рядового года приезжали целиком ради списка
/// заголовков. Вторая отдаёт в перечне число дней, а сами дни — в карточке
/// седмицы; так и берём, по одному запросу на раскрытую седмицу.
///
/// Раскрытое не перезапрашивается: свернули и открыли снова — дни уже здесь.
class WeekTile extends StatefulWidget {
  const WeekTile({super.key, required this.week, required this.title});

  final WeekWithDays week;
  final String title;

  @override
  State<WeekTile> createState() => _WeekTileState();
}

class _WeekTileState extends State<WeekTile> {
  Future<List<DayTexts>>? _days;

  void _load() {
    if (_days != null) return;
    final alias = widget.week.alias;
    // Без псевдонима спрашивать нечего: показываем то, что приехало с перечнем
    // (обыкновенно ничего), вместо запроса в никуда.
    _days = alias == null || alias.isEmpty
        ? Future.value(widget.week.days)
        : getWeekDays(alias);
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(widget.title),
      onExpansionChanged: (open) {
        if (open) setState(_load);
      },
      children: [
        if (_days == null)
          const SizedBox.shrink()
        else
          FutureBuilder<List<DayTexts>>(
            future: _days,
            builder: (context, future) {
              if (future.hasError) {
                return ListTile(
                  title: Text("Не удалось открыть седмицу",
                      style: Theme.of(context).textTheme.bodySmall),
                );
              }
              if (!future.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return Column(
                children: future.data!
                    .map((day) => ListTile(
                          title: Text(day.name ?? ""),
                          onTap: () => Navigator.pushNamed(
                            context,
                            "/days",
                            // Псевдонимом: вторая версия API спрашивает день по нему.
                            arguments: day.alias ?? day.id,
                          ),
                        ))
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}
