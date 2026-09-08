import 'package:flutter/material.dart';

import '../dto/bible.dart';
import '../utils/bible_style.dart';

/// Выбор изданий для параллельного чтения.
///
/// Возвращает новый набор кодов или `null`, если читатель закрыл лист, ничего не
/// решив. Порядок — порядок изданий с сервера, а не порядок нажатий: иначе одна и
/// та же пара изданий давала бы разный вид на разных заходах.
Future<List<String>?> showEditionPicker(
  BuildContext context, {
  required List<BibleEdition> editions,
  required List<String> selected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EditionPicker(editions: editions, selected: selected),
  );
}

class _EditionPicker extends StatefulWidget {
  const _EditionPicker({required this.editions, required this.selected});

  final List<BibleEdition> editions;
  final List<String> selected;

  @override
  State<_EditionPicker> createState() => _EditionPickerState();
}

class _EditionPickerState extends State<_EditionPicker> {
  late Set<String> chosen;

  @override
  void initState() {
    super.initState();
    chosen = widget.selected.toSet();
  }

  /// Порядок берётся из списка изданий, а не из порядка нажатий.
  List<String> get _ordered => widget.editions
      .map((edition) => edition.code)
      .where(chosen.contains)
      .toList();

  void _toggle(BibleEdition edition, bool value) {
    setState(() {
      if (value) {
        chosen.add(edition.code);
        return;
      }
      // Последнее издание снять нельзя. Пустой набор для сервера значит не
      // «покажи ничего», а «покажи все» — то есть читатель, сняв последнюю
      // галочку, увидел бы не пустоту, а неожиданно все шесть изданий сразу.
      // Проще не дать снять, чем объяснять.
      if (chosen.length > 1) chosen.remove(edition.code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
            child: Text(
              "Издания",
              style: TextStyle(fontFamily: "OldStandard", fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
            child: Text(
              "Выбрано больше одного — стихи показываются подряд, издание под изданием.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: widget.editions.map(_tile).toList(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Отмена"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _ordered),
                    child: const Text("Показать"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BibleEdition edition) {
    final reason = editionUnavailableReason(edition);
    final parts = <String>[];
    final year = edition.year;
    if (year != null) parts.add("$year");
    if (reason != null) parts.add(reason);
    final subtitle = parts.join(" · ");

    return CheckboxListTile(
      dense: true,
      value: chosen.contains(edition.code),
      // Издание, которое нечем нарисовать, выключено, а не спрятано: спрятанное
      // выглядело бы как «у них этого нет», а это неправда — оно есть, просто в
      // сборке нет шрифта для этого письма.
      onChanged: reason != null ? null : (value) => _toggle(edition, value == true),
      title: Text(
        edition.title,
        style: const TextStyle(fontFamily: "OldStandard", fontSize: 14.0),
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
    );
  }
}
