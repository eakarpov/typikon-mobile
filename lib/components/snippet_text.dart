import 'package:flutter/material.dart';

import '../dto/chant.dart';
import '../utils/reading_style.dart';

/// Найденный фрагмент с подсвеченным совпадением.
///
/// Сервер отдаёт фрагмент уже разобранным на куски — `[{text, hit}]`, — и это
/// единственная причина, по которой подсветка здесь возможна вообще. Искать
/// совпадение подстрокой на своей стороне нельзя: поиск идёт по нормализованной
/// форме, а показывается исходная, с ударениями и титлами, — подстрока
/// промахнулась бы чаще, чем попала, а промах подсветки читается как «нашли не
/// то».
///
/// Поэтому в соседней вкладке, где фрагмент приходит строкой, подсветки нет и не
/// будет: лучше не подсвечивать вовсе, чем подсвечивать наугад.
class SnippetText extends StatelessWidget {
  const SnippetText({
    super.key,
    required this.parts,
    required this.fontSize,
    this.fontFamily = "OldStandard",
  });

  final List<SnippetPart> parts;
  final double fontSize;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    final color = readingTextColor(context);
    final base = TextStyle(fontFamily: fontFamily, fontSize: fontSize, color: color);

    // Подложка выбирается по светлоте текста: в тёмной теме белое на бледно-жёлтом
    // не читается. Тот же приём, что в highlighted_text.dart для заметок.
    final highlight = color.computeLuminance() > 0.5
        ? const Color(0xFF5A4A00)
        : const Color(0xFFFFF3B0);

    return RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        style: base,
        children: parts
            .map((part) => TextSpan(
                  text: part.text,
                  style: part.hit
                      ? base.copyWith(backgroundColor: highlight, fontWeight: FontWeight.bold)
                      : base,
                ))
            .toList(),
      ),
    );
  }
}
