import 'package:flutter/material.dart';

import '../utils/selected_word.dart';
import 'report_error_sheet.dart';
import 'word_sheet.dart';

/// Один "контейнер" текста, к которому можно привязать зачало/заметку —
/// абзац (с индексом) или стих (глава+номер). Тот же список источников,
/// что раньше уходил в WordReportContext, просто без разбивки на слова —
/// выделение теперь произвольной длины (SelectionArea), не одно слово.
class TextContainer {
  final String text;
  final int? paragraphIndex;
  final int? chapter;
  final int? verse;

  const TextContainer.paragraph({required this.paragraphIndex, required this.text})
      : chapter = null, verse = null;

  const TextContainer.verse({required this.chapter, required this.verse, required this.text})
      : paragraphIndex = null;

  bool get isVerse => chapter != null && verse != null;
}

/// Оборачивает [child] в SelectionArea и дополняет системное меню выделения.
///
/// Выделено одно слово — «Ударение и разбор», всякому. «Сообщить об ошибке» и
/// «Добавить заметку» — только когда [enabled] (вошли) и выделение целиком
/// попадает в один из [containers]: выделение вне контейнера или через границу
/// двух сразу наших пунктов не предлагает (тот же принцип, что и на вебе —
/// data-report-container не найден).
class SelectionMenu extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final String textId;
  final List<TextContainer> containers;

  const SelectionMenu({
    super.key,
    required this.child,
    required this.enabled,
    required this.textId,
    required this.containers,
  });

  /// Только ударение и системные пункты — для Библии, канонов, акафистов и
  /// молитв. Заметки и сообщения об ошибке пишутся на тексты библиотеки по их
  /// идентификатору, а у главы Библии и у песнопения идентификатор из другого
  /// собрания: заметку сервер приписал бы не туда или не принял вовсе.
  const SelectionMenu.wordsOnly({super.key, required this.child})
      : enabled = false,
        textId = "",
        containers = const [];

  @override
  State<SelectionMenu> createState() => _SelectionMenuState();
}

class _SelectionMenuState extends State<SelectionMenu> {
  String? _lastSelection;

  TextContainer? _matchContainer(String phrase) {
    for (final c in widget.containers) {
      if (c.text.contains(phrase)) return c;
    }
    return null;
  }

  void _openReport(BuildContext context, TextContainer container, String phrase) {
    showReportErrorSheet(
      context,
      textId: widget.textId,
      contextText: container.text,
      phrase: phrase,
      paragraphIndex: container.paragraphIndex,
      chapter: container.chapter,
      verse: container.verse,
    );
  }

  void _openAddNote(BuildContext context, TextContainer container, String phrase) {
    showAddNoteSheet(
      context,
      textId: widget.textId,
      contextText: container.text,
      phrase: phrase,
      paragraphIndex: container.paragraphIndex,
      chapter: container.chapter,
      verse: container.verse,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (content) {
        _lastSelection = content?.plainText;
      },
      contextMenuBuilder: (context, state) {
        final phrase = _lastSelection?.trim() ?? "";
        final word = selectedWord(phrase);
        // Заметки и сообщения об ошибке требуют аккаунта, а ударение и
        // «Копировать» — нет: прочесть слово и скопировать стих вправе всякий.
        final container =
            widget.enabled && phrase.isNotEmpty ? _matchContainer(phrase) : null;

        // Системные пункты («Копировать», «Выделить всё») остаются при наших, а
        // не заменяются ими: прежде вошедший, выделив абзац, скопировать его не
        // мог — в меню были только две наши кнопки.
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            // Первым: долгое нажатие выделяет ровно слово, и за ним чаще всего
            // и приходят.
            if (word != null)
              ContextMenuButtonItem(
                label: "Ударение и разбор",
                onPressed: () {
                  state.hideToolbar();
                  showWordSheet(context, word);
                },
              ),
            ...state.contextMenuButtonItems,
            if (container != null) ...[
              ContextMenuButtonItem(
                label: "Сообщить об ошибке",
                onPressed: () {
                  state.hideToolbar();
                  _openReport(context, container, phrase);
                },
              ),
              ContextMenuButtonItem(
                label: "Добавить заметку",
                onPressed: () {
                  state.hideToolbar();
                  _openAddNote(context, container, phrase);
                },
              ),
            ],
          ],
        );
      },
      child: widget.child,
    );
  }
}
