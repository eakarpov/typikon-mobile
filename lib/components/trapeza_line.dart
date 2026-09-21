import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../apiMapper/trapeza.dart';
import '../dto/trapeza.dart';

/// Строка о трапезе над чтениями дня.
///
/// Три правила, и все три — про то, когда молчать.
///
/// **Загрузка не показывается.** За ответом стоит служба устава, которая
/// отвечает до восьми секунд; крутилка над чтениями задержала бы то, за чем
/// читатель пришёл. Строка появляется, когда появляется, — и до тех пор на её
/// месте ничего нет, даже пустого отступа.
///
/// **Отказ не показывается тоже.** Пост — дополнение к службе дня, а не она
/// сама, и «не удалось загрузить» над чтениями подняло бы дополнение над
/// главным.
///
/// **Спор глав показывается.** «Главы Типикона на этот день расходятся» — это
/// ответ, а не его отсутствие, и подменять его молчанием нельзя.
class TrapezaLine extends StatefulWidget {
  const TrapezaLine({super.key, required this.date});

  final DateTime date;

  @override
  State<TrapezaLine> createState() => _TrapezaLineState();
}

class _TrapezaLineState extends State<TrapezaLine> {
  late Future<Trapeza> trapeza;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TrapezaLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_key(oldWidget.date) != _key(widget.date)) setState(_load);
  }

  static String _key(DateTime date) => DateFormat("yyyy-MM-dd").format(date);

  void _load() {
    trapeza = getTrapeza(_key(widget.date));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Trapeza>(
      future: trapeza,
      builder: (context, future) {
        // Пока идёт запрос за новый день, строку прежнего не показываем: пост
        // вчерашнего дня под сегодняшней датой хуже пустого места.
        if (future.connectionState != ConnectionState.done ||
            !future.hasData ||
            !future.data!.hasLine) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2.0, right: 8.0),
                child: Icon(
                  Icons.restaurant_outlined,
                  size: 16.0,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Expanded(
                child: Text(
                  future.data!.line!,
                  style: const TextStyle(fontFamily: "OldStandard"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
