import 'package:flutter/material.dart';

import 'package:typikon/dto/calendar.dart';
import 'package:typikon/dto/user_note.dart';
import 'package:typikon/components/highlighted_text.dart';

/// Рендер списка стихов Библии/зачала с надстрочным номером стиха перед
/// каждым. Простой текст без markup сносок/ссылок — в отличие от
/// FusionTextWidgets, тексту Библии это не нужно. Выделение (для "Сообщить
/// об ошибке"/"Добавить заметку") оборачивается снаружи — см. SelectionMenu
/// в text_page.dart, этот виджет о нём не знает. notes — уже сохранённые
/// заметки для подсветки (пусто — просто обычный текст, как раньше).
class VerseListView extends StatelessWidget {
  final List<PericopeVerse> verses;
  final double fontSize;
  final String fontFamily;
  final List<UserNote> notes;
  final void Function(UserNote note)? onTapNote;

  const VerseListView({
    super.key,
    required this.verses,
    required this.fontSize,
    this.fontFamily = "OldStandard",
    this.notes = const [],
    this.onTapNote,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(fontFamily: fontFamily, fontSize: fontSize);
    final numberStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize * 0.7,
      fontFeatures: const [FontFeature.superscripts()],
      color: Colors.red,
      fontWeight: FontWeight.bold,
    );
    return RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        style: baseStyle,
        children: verses.expand((v) {
          final notesForVerse = notes.where((n) =>
              n.selection.type == 'verse' && n.selection.chapter == v.chapter && n.selection.verse == v.verse
          ).toList();
          return [
            TextSpan(text: "${v.verse} ", style: numberStyle),
            ...buildHighlightedSpans("${v.content} ", baseStyle, notesForVerse, onTapNote ?? (_) {}),
          ];
        }).toList(),
      ),
    );
  }
}
