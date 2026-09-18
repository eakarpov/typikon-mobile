import "dart:ui";
import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import "package:typikon/components/saints.dart";
import 'package:typikon/dto/user_note.dart';
import 'package:typikon/utils/reading_style.dart';

List<InlineSpan> buildPlaces(
  String text,
  double size,
  BuildContext context,
  String fontFamily, [
  List<UserNote>? notes,
  void Function(UserNote)? onTapNote,
]) {
  // Ключ и подпись — двумя группами, и обе закрыты по построению. Прежде здесь
  // стояло жадное `(.+)`: два места в одном абзаце давали ОДНУ ссылку, чья
  // подпись тянулась от первой метки до последней, а второе место исчезало
  // вместе с текстом между ними. Метка без подписи — `{pl|foo}` — роняла абзац
  // `RangeError`-ом на обращении к несуществующей второй части.
  final regex = RegExp(r"\{pl\|([^|}]+)(?:\|([^}]*))?\}");

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
            color: readingTextColor(context),
          ),
          children: buildSaints(
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

    final key = match.group(1);
    if (key != null) {
      // Пустая подпись показывает сам ключ: место названо неудачно, но абзац
      // цел и переход работает.
      final label = (match.group(2) ?? "").isEmpty ? key : match.group(2)!;
      widgets.add(
        TextSpan(
          text: label,
          recognizer: TapGestureRecognizer()..onTap = () {
            Navigator.pushNamed(context, "/places", arguments: key);
          },
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: size,
            color: Colors.blue,
          ),
          // children: [
          //   TextSpan(text: ),
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
          color: readingTextColor(context),
        ),
        children: buildSaints(
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
