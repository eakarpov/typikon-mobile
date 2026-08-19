import 'package:flutter/material.dart';

import 'package:typikon/dto/calendar.dart';
import 'package:typikon/components/word_report.dart';
import 'package:typikon/components/report_error_sheet.dart';

/// Рендер списка стихов Библии/зачала с надстрочным номером стиха перед
/// каждым. Простой текст без markup сносок/ссылок — в отличие от
/// FusionTextWidgets, тексту Библии это не нужно.
class VerseListView extends StatelessWidget {
  final List<PericopeVerse> verses;
  final double fontSize;
  final String fontFamily;
  final String? textId;
  final bool reportEnabled;

  const VerseListView({
    super.key,
    required this.verses,
    required this.fontSize,
    this.fontFamily = "OldStandard",
    this.textId,
    this.reportEnabled = false,
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
        children: verses.expand((v) {
          // Отдельный WordReportContext на каждый стих — индекс слова
          // считается заново с 0 внутри стиха.
          final report = (reportEnabled && textId != null)
              ? WordReportContext(
                  enabled: true,
                  onWordLongPress: (ctx, position, word, wordIndex) {
                    showWordReportMenu(
                      ctx,
                      position,
                      textId: textId!,
                      contextText: v.content,
                      word: word,
                      wordIndex: wordIndex,
                      chapter: v.chapter,
                      verse: v.verse,
                    );
                  },
                )
              : null;
          return [
            TextSpan(text: "${v.verse} ", style: numberStyle),
            ...tokenizeWords("${v.content} ", baseStyle, report, context),
          ];
        }).toList(),
      ),
    );
  }
}
