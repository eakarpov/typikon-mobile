import "dart:ui";
import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import "package:typikon/components/saints.dart";
import 'package:typikon/store/models/models.dart';

List<InlineSpan> buildPlaces(String text, double size, BuildContext context) {
  final regex = RegExp(r"\{pl\|(.+)}");

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
            fontFamily: "OldStandard",
            fontSize: size,
            color: StoreProvider.of<AppState>(context).state.settings.fontColor,
          ),
          children: buildSaints(
            beforeText,
            size,
            context,
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
            Navigator.pushNamed(context, "/places", arguments: matchStrings[0]);
          },
          style: TextStyle(
            fontFamily: "OldStandard",
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
          fontFamily: "OldStandard",
          fontSize: size,
          color: StoreProvider.of<AppState>(context).state.settings.fontColor,
        ),
        children: buildSaints(
          remainingText,
          size,
          context,
        ),
      ),
    );
  }
  return widgets;
}