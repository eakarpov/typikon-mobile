import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:typikon/dto/user_note.dart';

/// Разбивает [text] на TextSpan'ы, подсвечивая вхождения phrase каждой
/// заметки из [notes] (мягкий жёлтый фон — не меняет цвет/шрифт самого
/// текста, чтобы не сливаться, но и не перебивать чтение) с тапом,
/// открывающим заметку. Если заметок для этого текста нет — обычный
/// TextSpan(text: ...), как было до этой фичи.
List<InlineSpan> buildHighlightedSpans(
  String text,
  TextStyle style,
  List<UserNote> notes,
  void Function(UserNote note) onTapNote,
) {
  if (notes.isEmpty) {
    return [TextSpan(text: text, style: style)];
  }

  // Подложка подбирается под цвет самого текста, а не под тему: цвет чтений
  // может быть и выбран пользователем вручную. Светлый текст (тёмная тема) на
  // бледно-жёлтом не читается, поэтому для него берём тёмную янтарную подложку.
  final textColor = style.color;
  final isLightText = textColor == null || textColor.computeLuminance() > 0.5;
  final highlightStyle = style.copyWith(
    backgroundColor: isLightText ? const Color(0xFF5A4A00) : const Color(0xFFFFF3B0),
  );
  final spans = <InlineSpan>[];
  int cursor = 0;

  while (cursor < text.length) {
    int bestIndex = -1;
    UserNote? bestNote;
    for (final note in notes) {
      final phrase = note.selection.phrase;
      if (phrase.isEmpty) continue;
      final idx = text.indexOf(phrase, cursor);
      if (idx == -1) continue;
      if (bestIndex == -1 || idx < bestIndex) {
        bestIndex = idx;
        bestNote = note;
      }
    }
    if (bestIndex == -1 || bestNote == null) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
      break;
    }
    if (bestIndex > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, bestIndex), style: style));
    }
    final phrase = bestNote.selection.phrase;
    final note = bestNote;
    spans.add(TextSpan(
      text: phrase,
      style: highlightStyle,
      recognizer: TapGestureRecognizer()..onTap = () => onTapNote(note),
    ));
    cursor = bestIndex + phrase.length;
  }

  return spans;
}
