
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:typikon/utils/text.dart';
import "package:typikon/components/places.dart";
import 'package:typikon/dto/user_note.dart';
import 'package:typikon/utils/reading_style.dart';

List<InlineSpan> buildFootlinks(
    String text,
    double size,
    BuildContext context,
    List<String> footnotes,
    String fontFamily, [
    List<UserNote>? notes,
    void Function(UserNote)? onTapNote,
]) {
  final regex = RegExp(r"\{(\d+)}");

  final matches = regex.allMatches(text);

  final widgets = <InlineSpan>[];
  int currentIndex = 0;

  for (final match in matches) {
    final beforeText = text.substring(currentIndex, match.start);

    if (beforeText.isNotEmpty) {
      widgets.add(
        TextSpan(
          // text: beforeText,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: size,
            height: readingLineHeight(context),
            color: readingTextColor(context),
          ),
          children: buildPlaces(
            beforeText,
            size,
            context,
            fontFamily,
            notes,
            onTapNote,
          ),
        ),
      );
    }

    if (match.group(1) != null) {
      widgets.add(
        TextSpan(
          text: " [${match.group(1)}]",
          recognizer: TapGestureRecognizer()..onTap = () {
            showModalBottomSheet<void>(
              context: context,
              builder: (BuildContext context) {
                final footnote = footnoteAt(footnotes, match.group(1)) ??
                    "Сноска с этим номером в тексте не найдена.";
                // Высота по содержимому и прокрутка: в прежние сто точек
                // длинная сноска не помещалась и обрезалась.
                return SafeArea(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 100,
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(footnote),
                    ),
                  ),
                );
              },
            );
          },
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: size,
            height: readingLineHeight(context),
            color: readingLinkColor(context),
          ),
          // children: [
            // TextSpan(text: " [${match.group(1)}]"),
          // ],
        ),
      );
    }

    currentIndex = match.end;
  }

  final remainingText = text.substring(currentIndex);
  if (remainingText.isNotEmpty) {
    widgets.add(
      TextSpan(
        // text: remainingText,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          height: readingLineHeight(context),
          color: readingTextColor(context),
        ),
        children: buildPlaces(
          remainingText,
          size,
          context,
          fontFamily,
          notes,
          onTapNote,
        ),
      ),
    );
  }
  return widgets;
}
