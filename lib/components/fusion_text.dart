import "dart:ui";
import 'dart:async';
import 'dart:io';

import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter/material.dart';

import 'package:typikon/store/models/models.dart';
import 'package:typikon/components/footlinks.dart';

class FusionTextWidgets extends StatelessWidget {
  final String text;
  static final regex = RegExp(r"\{k\|(.+)}");

  const FusionTextWidgets({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble(),
              color: Colors.black,
            ),
            children: buildFootlinks(
                beforeText,
                StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
            ),
          ),
        );
      }

      if (match.group(1) != null) {
        widgets.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(
              fontFamily: "OldStandard",
              fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble(),
              color: Colors.red,
            ),
            // children: buildFootlinks(
            //     match.group(1) as String,
            //     StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
            // ),
            // children: FusionTextFootlinkWidgets(text: match.group(1) as String),
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
            fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble(),
            color: Colors.black,
          ),
          children: buildFootlinks(
              remainingText,
              StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble()
          ),
        ),
      );
    }

    return RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        children: widgets,
      ),
    );
  }
}

