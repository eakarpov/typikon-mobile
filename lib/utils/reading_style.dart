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
