import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../store/actions/actions.dart';
import '../store/models/models.dart';
import '../utils/chant_style.dart';
import '../utils/script_convert.dart';

/// Выбранное читателем письмо.
String readerScript(BuildContext context) =>
    StoreProvider.of<AppState>(context).state.settings.script;

/// Шрифт под выбранное письмо.
String readerFont(BuildContext context, String font, TextScript source) =>
    presentFont(font, source, readerScript(context));

/// Строки песнопения выбранным письмом. Переводится текст целиком, до разбивки
/// на строки: косая черта — не пробел, и вария перед ней не ставится, как и
/// положено в конце строки.
List<String> readerChantLines(BuildContext context, String text, TextScript source) =>
    chantLines(presentScript(text, source, readerScript(context)));

/// Кнопка в шапке: этот текст — другим письмом или как набран.
///
/// Меняет общую настройку, а не вид одного экрана: кто переключил Библию на
/// гражданку, хочет гражданку и в следующей главе. [onChanged] — чтобы экран
/// перерисовался: состояние он читает в `build`, а не слушает.
class ScriptToggle extends StatelessWidget {
  const ScriptToggle({super.key, required this.source, required this.onChanged});

  final TextScript source;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (source == TextScript.other) return const SizedBox.shrink();
    final converted = convertsScript(source, readerScript(context));
    return IconButton(
      icon: Icon(converted ? Icons.font_download : Icons.font_download_outlined),
      tooltip: converted
          ? "Как набрано"
          : (source == TextScript.church ? "Гражданкой" : "Уставом"),
      onPressed: () {
        final wanted = converted
            ? scriptAsSource
            : (source == TextScript.church ? scriptCivil : scriptChurch);
        StoreProvider.of<AppState>(context).dispatch(ChangeScriptAction(wanted));
        onChanged();
      },
    );
  }
}

/// Оговорка под переведённым текстом. Обязательна по той же причине, что и у
/// машинных ударений: без неё перевод по правилам выдавался бы за книгу.
class ScriptCaveat extends StatelessWidget {
  const ScriptCaveat({super.key, required this.source});

  final TextScript source;

  @override
  Widget build(BuildContext context) {
    final setting = readerScript(context);
    if (!convertsScript(source, setting)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Text(
        source == TextScript.church
            ? "Гражданкой по правилам, а не как в книге. Слова под титлом оставлены "
                "книжными: сокращение без словаря не раскрыть."
            : "Уставом по правилам, а не как в книге: придыхания, «є», «ꙗ», «ᲂу», «і», "
                "ер и вария выведены из написания, а ятей, омег и титл нет — их по "
                "правилу не вывести.",
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
