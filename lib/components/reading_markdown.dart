import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:typikon/utils/reading_style.dart';

/// Размеченный текст — по настройкам читателя.
///
/// Разметка встречается в двух местах, и оба не знали о настройках чтения
/// вовсе. Житие святого набиралось шрифтом чтений, но размером, цветом и
/// интервалом — системными. А текст с `newUi` уходил в голый `Markdown` внутри
/// `SizedBox(height: 350)`: маленькое окошко со своей прокруткой посреди
/// страницы, где ни размер, ни цвет, ни интервал, ни ширина колонки не значили
/// ничего. Человек, выставивший себе крупный шрифт, на таком тексте получал
/// обычный.
///
/// [scrollable] — прокручивается ли сам. `false` для встраивания в страницу,
/// которая прокручивается своими силами: вложенная прокрутка и есть та самая
/// беда с окошком в 350 точек.
class ReadingMarkdown extends StatelessWidget {
  const ReadingMarkdown(this.data, {super.key, this.scrollable = true});

  final String data;
  final bool scrollable;

  MarkdownStyleSheet _styleSheet(BuildContext context) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    final body = readingTextStyle(context);

    // Заголовки следуют за размером чтений, но крупнее его: разметка в житиях
    // пользуется ими, и прибитые системные размеры рядом с крупным текстом
    // выглядели бы мельче него.
    TextStyle? heading(TextStyle? from, double scale) =>
        from?.copyWith(fontFamily: body.fontFamily, fontSize: body.fontSize! * scale);

    return base.copyWith(
      p: body,
      textAlign: readingWrapAlignment(context),
      listBullet: body,
      blockquote: body,
      h1: heading(base.h1, 1.6),
      h2: heading(base.h2, 1.4),
      h3: heading(base.h3, 1.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final styleSheet = _styleSheet(context);

    if (!scrollable) {
      return MarkdownBody(data: data, styleSheet: styleSheet);
    }
    return Markdown(data: data, styleSheet: styleSheet);
  }
}
