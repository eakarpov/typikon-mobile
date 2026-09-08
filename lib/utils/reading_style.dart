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
