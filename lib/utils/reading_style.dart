import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:typikon/store/models/models.dart';

/// Цвет текста чтений: явный выбор пользователя, иначе — цвет из темы.
///
/// Фоллбек обязателен именно здесь. `Text` сливает свой стиль с
/// `DefaultTextStyle` и при `color == null` берёт цвет темы сам, а
/// `RichText`/`TextSpan` ничего не наследуют: при `color == null` движок
/// рисует текст белым, то есть в светлой теме — белым по белому. Весь текст
/// чтений рисуется именно через RichText.
Color readingTextColor(BuildContext context) {
  final chosen = StoreProvider.of<AppState>(context).state.settings.fontColor;
  if (chosen != null) return chosen;
  final theme = Theme.of(context);
  return theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;
}

/// Фон страницы чтения: выбор читателя, иначе — фон темы.
///
/// Заведено, когда обнаружилось, что каноны, акафисты и молитвы фон читателя
/// не берут: они писались после прочих и повторили `Theme.of(context)` вместо
/// настройки. Одно место лучше семи одинаковых выражений.
Color readingBackgroundColor(BuildContext context) {
  final settings = StoreProvider.of<AppState>(context).state.settings;
  return settings.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
}

/// Междустрочный интервал чтений.
///
/// Церковнославянский набор несёт надстрочные знаки, и при тесных строках они
/// сливаются со строкой над собой; полтора — то же значение, что взял сайт.
double readingLineHeight(BuildContext context) =>
    StoreProvider.of<AppState>(context).state.settings.lineHeight;

/// Выключка чтений.
///
/// По ширине — как в книге и как на сайте; переносов у нас нет, и кому прогалины
/// мешают больше неровного края, тот выбирает левый.
TextAlign readingTextAlign(BuildContext context) =>
    StoreProvider.of<AppState>(context).state.settings.readingAlign == "left"
        ? TextAlign.left
        : TextAlign.justify;

/// Цвет ссылки в тексте чтения — сноски, названия мест, имена святых.
///
/// Подбирается по светлоте самого текста, а не по теме: цвет чтений читатель
/// мог выбрать вручную, и тогда тема о нём ничего не говорит (то же правило у
/// подложки заметок в `components/highlighted_text.dart`). Прибитый `Colors.blue`
/// на тёмном фоне сливался с ним настолько, что сноску было не разглядеть.
Color readingLinkColor(BuildContext context) {
  final isLightText = readingTextColor(context).computeLuminance() > 0.5;
  return isLightText ? const Color(0xFF82B1FF) : const Color(0xFF1565C0);
}

/// Размер текста чтений, выбранный читателем.
double readingFontSize(BuildContext context) =>
    StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble();

/// Стиль текста чтения — все настройки читателя разом.
///
/// Их шесть: размер, цвет, фон, интервал, выключка и ширина колонки. Собирались
/// они в каждом месте заново, и половина мест про половину настроек не знала:
/// калькулятор не брал ни цвет, ни выключку, страница дня прибивала выключку к
/// `justify` и забывала интервал, а разметка Markdown не знала ни об одной.
/// Настройка, которую половина экранов не соблюдает, хуже отсутствующей: человек
/// её выставил и считает, что она действует.
///
/// [churchSlavonic] — набран ли текст церковнославянским: у него свой шрифт
/// (Monomakh), потому что OldStandard не несёт ни надстрочных знаков, ни
/// буквенных цифр (см. utils/bible_style.dart).
TextStyle readingTextStyle(
  BuildContext context, {
  bool churchSlavonic = false,
  bool italic = false,
}) {
  return TextStyle(
    fontFamily: churchSlavonic ? "Monomakh" : "OldStandard",
    fontSize: readingFontSize(context),
    height: readingLineHeight(context),
    color: readingTextColor(context),
    fontStyle: italic ? FontStyle.italic : null,
  );
}

/// Проза чтения: строка, набранная по настройкам читателя.
///
/// Для всего, что рисуется обычным [Text], — содержимое чтения на странице дня
/// и в калькуляторе, пояснения, жития. Текст со сносками, местами и заметками
/// идёт мимо: он собирается из кусков и живёт в `components/fusion_text.dart`,
/// но стиль берёт отсюда же.
class ReadingText extends StatelessWidget {
  const ReadingText(
    this.text, {
    super.key,
    this.churchSlavonic = false,
    this.italic = false,
  });

  final String text;
  final bool churchSlavonic;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: readingTextAlign(context),
      style: readingTextStyle(
        context,
        churchSlavonic: churchSlavonic,
        italic: italic,
      ),
    );
  }
}

/// Та же выключка, что и у [readingTextAlign], но в виде `WrapAlignment` —
/// её ждёт таблица стилей разметки.
WrapAlignment readingWrapAlignment(BuildContext context) =>
    readingTextAlign(context) == TextAlign.left
        ? WrapAlignment.start
        : WrapAlignment.spaceBetween;

/// Колонка чтения заданной читателем ширины.
///
/// Без выбора не делает ничего: на телефоне ограничивать нечего, а лишний
/// `Center` посреди списка сместил бы то, что и так во всю ширину.
class ReadingColumn extends StatelessWidget {
  const ReadingColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final measure =
        StoreProvider.of<AppState>(context).state.settings.readingMeasure;
    if (measure == null) return child;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: measure),
        child: child,
      ),
    );
  }
}
