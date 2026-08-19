import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef WordLongPressCallback = void Function(
  BuildContext context,
  Offset globalPosition,
  String word,
  int wordIndex,
);

/// Пробрасывается через дерево fusion_text→footlinks→places→saints и
/// verse_list, чтобы листовые прогоны простой прозы (там, где сейчас цельный
/// TextSpan с сырым текстом) получали долгий тап по слову. Один экземпляр —
/// один контейнер отсчёта индекса (один абзац или один стих); индекс не
/// учитывает текст сносок/ссылок на святых/места — это отдельные span'ы со
/// своим TapGestureRecognizer, у TextSpan он может быть только один.
class WordReportContext {
  final bool enabled;
  final WordLongPressCallback onWordLongPress;
  int _wordIndex = 0;

  WordReportContext({
    required this.enabled,
    required this.onWordLongPress,
  });
}

final RegExp _wordPattern = RegExp(r'\S+');

/// Разбивает [text] на слова с долгим тапом, если [report] задан и включён;
/// иначе — как раньше, один обычный TextSpan без изменений в рендере.
List<InlineSpan> tokenizeWords(
  String text,
  TextStyle style,
  WordReportContext? report,
  BuildContext context,
) {
  if (report == null || !report.enabled || text.trim().isEmpty) {
    return [TextSpan(text: text, style: style)];
  }

  final spans = <InlineSpan>[];
  int cursor = 0;
  for (final match in _wordPattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start), style: style));
    }
    final word = match.group(0)!;
    final index = report._wordIndex++;
    spans.add(TextSpan(
      text: word,
      style: style,
      recognizer: LongPressGestureRecognizer()
        ..onLongPressStart = (details) {
          report.onWordLongPress(context, details.globalPosition, word, index);
        },
    ));
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: style));
  }
  return spans;
}
