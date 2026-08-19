import 'package:flutter/material.dart';

import 'package:typikon/dto/calendar.dart';
import 'package:typikon/utils/signs.dart';

/// Компактный информационный блок "Святые дня" по месяцеслову Типикона
/// (коллекция signs на бекенде). Не имеет связи с текстами/святыми (id),
/// поэтому пункты не тапаются — только ссылка "Все святые дня" на
/// существующую страницу /dneslov/memories за подробными житиями.
class DayMemoriesView extends StatelessWidget {
  final DayMemories memories;

  const DayMemoriesView({super.key, required this.memories});

  Widget _row(DayMemory memory, {required bool isDefault}) {
    final glyph = signGlyph(memory.sign);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: "OldStandard",
            color: Colors.black,
            fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
          ),
          children: [
            if (glyph != null) TextSpan(
              text: "${glyph.glyph} ",
              style: TextStyle(color: glyph.color),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Святые дня", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          if (memories.defaultMemory != null) _row(memories.defaultMemory!, isDefault: true),
          ...memories.secondary.map((m) => _row(m, isDefault: false)),
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
