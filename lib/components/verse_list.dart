import 'package:flutter/material.dart';

import 'package:typikon/dto/calendar.dart';
import 'package:typikon/dto/user_note.dart';
import 'package:typikon/components/highlighted_text.dart';
import 'package:typikon/utils/reading_style.dart';
import 'package:typikon/utils/script_convert.dart';
import 'package:typikon/components/pinch_zoom.dart';
import 'package:typikon/components/script_toggle.dart';

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

  /// Каким письмом набраны стихи. Показываются тем, какое выбрал читатель
  /// (см. `utils/script_convert.dart`).
  final TextScript script;

  const VerseListView({
    super.key,
    required this.verses,
    required this.fontSize,
    this.fontFamily = "OldStandard",
    this.notes = const [],
    this.onTapNote,
    this.script = TextScript.other,
  });

  @override
  Widget build(BuildContext context) {
    final setting = readerScript(context);
    final fontFamily = presentFont(this.fontFamily, script, setting);
    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: readingLineHeight(context),
      color: readingTextColor(context),
    );
    final numberStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize * 0.7,
      fontFeatures: const [FontFeature.superscripts()],
      color: Colors.red,
      fontWeight: FontWeight.bold,
    );
    return RichText(
      textAlign: readingTextAlign(context),
      // Голый RichText в SelectionArea себя не записывает (см. fusion_text).
      selectionRegistrar: SelectionContainer.maybeOf(context),
      selectionColor: DefaultSelectionStyle.of(context).selectionColor,
      // Щипок на экране чтения (см. `components/pinch_zoom.dart`).
      textScaler: ReadingZoom.scalerOf(context),
      text: TextSpan(
        style: baseStyle,
        children: verses.expand((v) {
          final notesForVerse = notes.where((n) =>
              n.selection.type == 'verse' && n.selection.chapter == v.chapter && n.selection.verse == v.verse
          ).toList();
          return [
            TextSpan(text: "${v.verse} ", style: numberStyle),
            ...buildHighlightedSpans("${presentScript(v.content, script, setting)} ", baseStyle, notesForVerse, onTapNote ?? (_) {}),
          ];
        }).toList(),
      ),
    );
  }
}
