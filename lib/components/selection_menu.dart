import 'package:flutter/material.dart';

import 'report_error_sheet.dart';

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

/// Оборачивает [child] в SelectionArea с кастомным меню ("Сообщить об
/// ошибке" / "Добавить заметку") — но только когда [enabled] (вошли) и
/// выделение целиком попадает в один из [containers]. Иначе — обычное
/// системное меню (копировать и т.п.), выделение вне контейнера или через
/// границу двух сразу не предлагает наши пункты (тот же принцип, что и на
/// вебе — data-report-container не найден).
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
    if (!widget.enabled) return widget.child;

    return SelectionArea(
      onSelectionChanged: (content) {
        _lastSelection = content?.plainText;
      },
      contextMenuBuilder: (context, state) {
        final rawPhrase = _lastSelection?.trim();
        if (rawPhrase == null || rawPhrase.isEmpty) {
          return AdaptiveTextSelectionToolbar.selectableRegion(selectableRegionState: state);
        }
        final phrase = rawPhrase;
        final container = _matchContainer(phrase);
        if (container == null) {
          return AdaptiveTextSelectionToolbar.selectableRegion(selectableRegionState: state);
        }
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
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
        );
      },
      child: widget.child,
    );
  }
}
