import 'package:flutter/material.dart';

import 'package:typikon/dto/calendar.dart';

/// Рендер списка стихов Библии/зачала с надстрочным номером стиха перед
/// каждым. Простой текст без markup сносок/ссылок — в отличие от
/// FusionTextWidgets, тексту Библии это не нужно.
class VerseListView extends StatelessWidget {
  final List<PericopeVerse> verses;
  final double fontSize;
  final String fontFamily;

  const VerseListView({
    super.key,
    required this.verses,
    required this.fontSize,
    this.fontFamily = "OldStandard",
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(fontFamily: fontFamily, fontSize: fontSize);
    final numberStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize * 0.7,
      fontFeatures: const [FontFeature.superscripts()],
      color: Colors.red,
      fontWeight: FontWeight.bold,
    );
    return RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        style: baseStyle,
        children: verses.expand((v) => [
          TextSpan(text: "${v.verse} ", style: numberStyle),
          TextSpan(text: "${v.content} "),
        ]).toList(),
      ),
    );
  }
}
