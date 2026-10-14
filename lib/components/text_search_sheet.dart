import 'package:flutter/material.dart';

import 'package:typikon/utils/text_search.dart';

/// Шторка поиска внутри открытого текста: поле ввода, счётчик «N из M» и
/// стрелки листания. Совпадения считает и держит сама шторка — страница текста
/// при каждом изменении получает (совпадения, номер текущего) и подсвечивает
/// их, а к текущему прокручивает.
Future<void> showTextSearchSheet(
  BuildContext context, {
  required List<String> paragraphs,
  required void Function(Map<int, List<TextRange>> matches, int current) onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Padding(
        // Поле в фокусе поднимает клавиатуру — отступаем от неё, иначе шторку
        // её закроет.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          child: _TextSearchSheet(
            paragraphs: paragraphs,
            onChanged: onChanged,
          ),
        ),
      );
    },
  );
}

class _TextSearchSheet extends StatefulWidget {
  final List<String> paragraphs;
  final void Function(Map<int, List<TextRange>> matches, int current) onChanged;

  const _TextSearchSheet({
    required this.paragraphs,
    required this.onChanged,
  });

  @override
  State<_TextSearchSheet> createState() => _TextSearchSheetState();
}

class _TextSearchSheetState extends State<_TextSearchSheet> {
  final TextEditingController _controller = TextEditingController();

  Map<int, List<TextRange>> _matches = const {};
  int _current = 0;

  int get _total => flattenSearchMatches(_matches).length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Каждое изменение — новый запрос или шаг листания — уходит на страницу:
  /// она подсвечивает совпадения и прокручивает к текущему.
  void _emit() {
    widget.onChanged(_matches, _current);
  }

  void _applyQuery(String query) {
    final matches = searchParagraphs(widget.paragraphs, query);
    setState(() {
      _matches = matches;
      _current = 0;
    });
    _emit();
  }

  void _step(int delta) {
    final total = _total;
    if (total == 0) return;
    // По кругу: от последнего стрелка вниз ведёт к первому — листать
    // большой список кнопками иначе приходилось бы ловить первый и последний.
    var next = (_current + delta) % total;
    if (next < 0) next += total;
    setState(() => _current = next);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final hasMatches = total > 0;
    final shown = hasMatches ? _current + 1 : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 8.0, 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: "Искать в тексте",
                border: InputBorder.none,
              ),
              onChanged: _applyQuery,
              onSubmitted: (_) => _step(1),
            ),
          ),
          Text(
            hasMatches ? "$shown из $total" : "Нет совпадений",
            style: Theme.of(context).textTheme.labelMedium,
          ),
          IconButton(
            tooltip: "Предыдущее",
            onPressed: hasMatches ? () => _step(-1) : null,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: "Следующее",
            onPressed: hasMatches ? () => _step(1) : null,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          IconButton(
            tooltip: "Закрыть",
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
