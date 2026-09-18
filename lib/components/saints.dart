import "dart:ui";
import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:typikon/dto/user_note.dart';
import 'package:typikon/components/highlighted_text.dart';
import 'package:typikon/utils/reading_style.dart';

List<InlineSpan> buildSaints(
  String text,
  double size,
  BuildContext context,
  String fontFamily, [
  List<UserNote>? notes,
  void Function(UserNote)? onTapNote,
]) {
  // Опознаватель и подпись — двумя закрытыми группами; почему не жадное `(.+)`,
  // сказано в `places.dart`: метка здесь той же формы и ломалась так же.
  final regex = RegExp(r"\{st\|([^|}]+)(?:\|([^}]*))?\}");

  final matches = regex.allMatches(text);

  final widgets = <InlineSpan>[];
  int currentIndex = 0;

  for (final match in matches) {
    final beforeText = text.substring(currentIndex, match.start);

    if (beforeText.isNotEmpty) {
      final style = TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        color: readingTextColor(context),
      );
      widgets.add(
        TextSpan(
          children: (notes != null && notes.isNotEmpty)
              ? buildHighlightedSpans(beforeText, style, notes, onTapNote ?? (_) {})
              : [TextSpan(text: beforeText, style: style)],
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
    final style = TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      color: readingTextColor(context),
    );
    widgets.add(
      TextSpan(
        children: (notes != null && notes.isNotEmpty)
            ? buildHighlightedSpans(remainingText, style, notes, onTapNote ?? (_) {})
            : [TextSpan(text: remainingText, style: style)],
      ),
    );
  }
  return widgets;
}
