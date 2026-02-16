import "dart:ui";
import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:typikon/store/models/models.dart';

List<InlineSpan> buildSaints(String text, double size, BuildContext context, String fontFamily) {
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
            fontFamily: fontFamily,
            fontSize: size,
            color: StoreProvider.of<AppState>(context).state.settings.fontColor,
          ),
        ),
      );
    }

    if (match.group(1) != null) {
      List<String> matchStrings = (match.group(1) as String).split("|");
      widgets.add(
        TextSpan(
          text: matchStrings[1],
          recognizer: TapGestureRecognizer()..onTap = () {
            Navigator.pushNamed(context, "/saints", arguments: matchStrings[0]);
          },
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: size,
            color: Colors.blue,
          ),
          // children: [
          //   TextSpan(text: (match.group(1) as String).split("|")[1]),
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
        text: remainingText,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          color: StoreProvider.of<AppState>(context).state.settings.fontColor,
        ),
      ),
    );
  }
  return widgets;
}