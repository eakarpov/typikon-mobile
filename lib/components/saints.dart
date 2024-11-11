import "dart:ui";
import 'dart:async';
import 'dart:io';

import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';

List<InlineSpan> buildSaints(String text, double size) {
  final regex = RegExp(r"\{st\|(.+)}");

  final matches = regex.allMatches(text);

  final widgets = <InlineSpan>[];
  int currentIndex = 0;

  for (final match in matches) {
    final beforeText = text.substring(currentIndex, match.start);

    if (beforeText.isNotEmpty) {
      widgets.add(
        TextSpan(
          text: beforeText,
          style: TextStyle(
            fontFamily: "OldStandard",
            fontSize: size,
            color: Colors.black,
          ),
        ),
      );
    }

    if (match.group(1) != null) {
      widgets.add(
        TextSpan(
          // text: match.group(1),
          style: TextStyle(
            fontFamily: "OldStandard",
            fontSize: size,
            color: Colors.blue,
          ),
          children: [
            TextSpan(text: (match.group(1) as String).split("|")[1]),
          ],
        ),
      );
    }

    currentIndex = match.end;
  }

  final remainingText = text.substring(currentIndex);
  if (remainingText.isNotEmpty) {
    widgets.add(
      TextSpan(
        text: remainingText,
        style: TextStyle(
          fontFamily: "OldStandard",
          fontSize: size,
          color: Colors.black,
        ),
      ),
    );
  }
  return widgets;
}