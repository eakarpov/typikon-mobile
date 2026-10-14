import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:typikon/dto/user_note.dart';
import 'package:typikon/components/highlighted_text.dart';
import 'package:typikon/utils/reading_style.dart';
import 'package:typikon/utils/text_search.dart';

List<InlineSpan> buildSaints(
  String text,
  double size,
  BuildContext context,
  String fontFamily, [
  List<UserNote>? notes,
  void Function(UserNote)? onTapNote,
  List<TextRange> searchMatches = const [],
  TextRange? activeMatch,
]) {
  // Опознаватель и подпись — двумя закрытыми группами; почему не жадное `(.+)`,
  // сказано в `places.dart`: метка здесь той же формы и ломалась так же.
  final regex = RegExp(r"\{st\|([^|}]+)(?:\|([^}]*))?\}");

  final matches = regex.allMatches(text);

  final widgets = <InlineSpan>[];
  int currentIndex = 0;

  TextStyle plainStyle() => TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        color: readingTextColor(context),
      );

  for (final match in matches) {
    final beforeText = text.substring(currentIndex, match.start);

    if (beforeText.isNotEmpty) {
      widgets.add(
        TextSpan(
          children: buildHighlightedSpans(
            beforeText,
            plainStyle(),
            notes ?? const [],
            onTapNote ?? (_) {},
            searchMatches: searchMatches,
            activeMatch: activeMatch,
          ),
        ),
      );
    }

    final id = match.group(1);
    if (id != null) {
      final label = (match.group(2) ?? "").isEmpty ? id : match.group(2)!;
      widgets.add(
        TextSpan(
          text: label,
          recognizer: TapGestureRecognizer()..onTap = () {
            Navigator.pushNamed(context, "/saints", arguments: id);
          },
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: size,
            color: Colors.blue,
          ),
        ),
      );
    }

    currentIndex = match.end;
  }

  final remainingText = text.substring(currentIndex);
  if (remainingText.isNotEmpty) {
    widgets.add(
      TextSpan(
        children: buildHighlightedSpans(
          remainingText,
          plainStyle(),
          notes ?? const [],
          onTapNote ?? (_) {},
          searchMatches: searchMatches,
          activeMatch: activeMatch,
        ),
      ),
    );
  }
  return widgets;
}
