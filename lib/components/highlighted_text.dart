import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:typikon/dto/user_note.dart';
import 'package:typikon/utils/accents.dart';

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

  // Ищем БЕЗ ОГЛЯДКИ НА УДАРЕНИЯ, а красим по исходной строке.
  //
  // Текст чтения показывается в двух видах: как в книге и с машинными
  // ударениями. Заметка хранит то написание, при котором её завели, и точное
  // совпадение связывало бы её ровно с одним из двух видов: переключил — и
  // подсветка исчезла, без ошибки и без следа.
  while (cursor < text.length) {
    int bestStart = -1;
    int bestEnd = -1;
    UserNote? bestNote;

    for (final note in notes) {
      final found = findIgnoringAccents(text, note.selection.phrase, cursor);
      if (found == null) continue;
      if (bestStart == -1 || found.$1 < bestStart) {
        bestStart = found.$1;
        bestEnd = found.$2;
        bestNote = note;
      }
    }

    if (bestNote == null) {
      spans.add(TextSpan(text: text.substring(cursor), style: style));
      break;
    }
    if (bestStart > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, bestStart), style: style));
    }

    final note = bestNote;
    spans.add(TextSpan(
      // Показываем то, что стоит в тексте, а не то, что записано в заметке:
      // виды различаются знаками, и подставив написание заметки, мы нарисовали
      // бы посреди книги слово из другого вида.
      text: text.substring(bestStart, bestEnd),
      style: highlightStyle,
      recognizer: TapGestureRecognizer()..onTap = () => onTapNote(note),
    ));
    cursor = bestEnd;
  }

  return spans;
}
