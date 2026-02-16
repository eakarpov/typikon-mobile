import "dart:ui";
import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';
import 'package:typikon/store/models/models.dart';
import "package:typikon/components/places.dart";

List<InlineSpan> buildFootlinks(
    String text,
    double size,
    BuildContext context,
    List<String> footnotes,
    String fontFamily,
) {
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
            color: StoreProvider.of<AppState>(context).state.settings.fontColor,
          ),
          children: buildPlaces(
            beforeText,
            size,
            context,
            fontFamily,
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
                String footnote = footnotes[int.parse(match.group(1)??"0")]??"test";
                return Container(
                  height: 100,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(footnote),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: size,
            color: Colors.blue,
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
          color: StoreProvider.of<AppState>(context).state.settings.fontColor,
        ),
        children: buildPlaces(
          remainingText,
          size,
          context,
          fontFamily,
        ),
      ),
    );
  }
  return widgets;
}