import 'package:flutter/material.dart';

import 'package:typikon/dto/calendar.dart';
import 'package:typikon/utils/reading_style.dart';
import 'package:typikon/utils/signs.dart';

/// Компактный информационный блок "Святые дня" по месяцеслову Типикона
/// (коллекция signs на бекенде). Не имеет связи с текстами/святыми (id),
/// поэтому пункты не тапаются — только ссылка "Все святые дня" на
/// существующую страницу /dneslov/memories за подробными житиями.
class DayMemoriesView extends StatelessWidget {
  final DayMemories memories;

  const DayMemoriesView({super.key, required this.memories});

  /// [textColor] приходит снаружи, потому что RichText ничего не наследует:
  /// при color == null движок рисует текст белым. Раньше здесь стоял жёстко
  /// прибитый Colors.black — на тёмной теме святые дня были чёрным по тёмному.
  Widget _row(DayMemory memory, {required bool isDefault, required Color textColor}) {
    final glyph = signGlyph(memory.sign);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: "OldStandard",
            color: textColor,
            fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
          ),
          children: [
            if (glyph != null) TextSpan(
              text: "${glyph.glyph} ",
              style: TextStyle(color: glyph.color ?? textColor),
            ),
            TextSpan(text: memory.name),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty) return const SizedBox.shrink();
    final textColor = readingTextColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Святые дня", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          if (memories.defaultMemory != null)
            _row(memories.defaultMemory!, isDefault: true, textColor: textColor),
          ...memories.secondary.map((m) => _row(m, isDefault: false, textColor: textColor)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              onPressed: () => Navigator.pushNamed(context, "/dneslov/memories"),
              child: const Text("Все святые дня →"),
            ),
          ),
        ],
      ),
    );
  }
}
