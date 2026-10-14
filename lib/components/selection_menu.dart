import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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

  /// Ссылка на выделенную фразу для «Поделиться»; `null` — пункта нет.
  ///
  /// Возвращает полный текст отправки (фраза плюс ссылка) или `null`, если
  /// делиться нечем. Пункт рисуется в общем `contextMenuBuilder`, поэтому
  /// стоит и в полном режиме, и в `wordsOnly`.
  final String? Function(String phrase)? shareLinkFor;

  /// Дополнительные пункты тулбара — после «Ударения и разбора», перед
  /// системными. Возвращают виджеты кнопок (`TextSelectionToolbarTextButton`
  /// с тем же видом, что у соседних пунктов); `container` — контейнер, в
  /// который попало выделение, или `null`, если ни в один.
  final List<Widget> Function(String phrase, TextContainer? container)? extraItems;

  const SelectionMenu({
    super.key,
    required this.child,
    required this.enabled,
    required this.textId,
    required this.containers,
    this.shareLinkFor,
    this.extraItems,
  });

  /// Только ударение и системные пункты — для Библии, канонов, акафистов и
  /// молитв. Заметки и сообщения об ошибке пишутся на тексты библиотеки по их
  /// идентификатору, а у главы Библии и у песнопения идентификатор из другого
  /// собрания: заметку сервер приписал бы не туда или не принял вовсе.
  ///
  /// [containers] здесь — не для заметок (они отключены вместе с [enabled]),
  /// а для [extraItems]: колбэк узнаёт, в какой стих попало выделение.
  const SelectionMenu.wordsOnly({
    super.key,
    required this.child,
    this.shareLinkFor,
    this.containers = const [],
    this.extraItems,
  })  : enabled = false,
        textId = "";

  @override
  State<SelectionMenu> createState() => _SelectionMenuState();
}

class _SelectionMenuState extends State<SelectionMenu> {
  String? _lastSelection;

  /// Регион выделения — виден, только пока открыт тулбар (contextMenuBuilder
  /// вызывается лишь для его сборки). Нужен, чтобы снять тулбар при уходе на
  /// другой маршрут: снаружи (из страницы) состояние региона не достать.
  SelectableRegionState? _region;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Зависимость от ModalRoute ставим здесь: когда поверх ложат другой экран
    // (из этого меню ушли в карточку), маршрут перестаёт быть текущим, и нам
    // звонят. Тулбар снимаем — иначе по возврату он встал бы поверх текста с
    // прежним выделением, будто меню никуда и не закрывалось.
    if (ModalRoute.of(context)?.isCurrent == false) {
      _region?.hideToolbar();
    }
  }

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

  /// Текст отправки «Поделиться»: выделенная фраза, а ссылку — за ней,
  /// отбитой пустой строкой, чтобы в мессенджере адрес не сливался с цитатой.
  void _share(String phrase) {
    final link = widget.shareLinkFor?.call(phrase);
    if (link == null) return;
    final trimmed = link.trim();
    SharePlus.instance.share(ShareParams(
      text: trimmed.isEmpty ? phrase : "$phrase\n\n$trimmed",
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (content) {
        _lastSelection = content?.plainText;
      },
      contextMenuBuilder: (context, state) {
        _region = state;
        final phrase = _lastSelection?.trim() ?? "";
        final word = selectedWord(phrase);
        // Заметки и сообщения об ошибке требуют аккаунта, а ударение и
        // «Копировать» — нет: прочесть слово и скопировать стих вправе всякий.
        // Контейнер ищем и без входа, если заданы дополнительные пункты:
        // иначе «В других изданиях» в главе Библии не увидело бы стиха.
        final wantsContainer =
            (widget.enabled || widget.extraItems != null) && phrase.isNotEmpty;
        final container = wantsContainer ? _matchContainer(phrase) : null;

        final extras = widget.extraItems?.call(phrase, container) ?? const <Widget>[];

        // Системные пункты («Копировать», «Выделить всё») остаются при наших, а
        // не заменяются ими: прежде вошедший, выделив абзац, скопировать его не
        // мог — в меню были только две наши кнопки.
        final items = <ContextMenuButtonItem>[
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
          // «Поделиться» не требует входа и подходит любому выделению,
          // не только слову целиком: выбрал полстроки — отправил полстроку.
          if (phrase.isNotEmpty && widget.shareLinkFor != null)
            ContextMenuButtonItem(
              label: "Поделиться",
              onPressed: () {
                state.hideToolbar();
                _share(phrase);
              },
            ),
          ...state.contextMenuButtonItems,
          if (widget.enabled && container != null) ...[
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
        ];

        if (extras.isEmpty) {
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: state.contextMenuAnchors,
            buttonItems: items,
          );
        }

        // С дополнительными виджетами тулбар собирается из children: соседние
        // пункты прогоняем через тот же getAdaptiveButtons, что вызывает
        // buttonItems, — и выглядят они неотличимо. Дополнительные встают
        // после «Ударения и разбора».
        final head = <ContextMenuButtonItem>[
          if (word != null) items.first,
        ];
        final tail = items.length > head.length
            ? items.sublist(head.length)
            : const <ContextMenuButtonItem>[];
        return AdaptiveTextSelectionToolbar(
          anchors: state.contextMenuAnchors,
          children: [
            ...AdaptiveTextSelectionToolbar.getAdaptiveButtons(context, head),
            ...extras,
            ...AdaptiveTextSelectionToolbar.getAdaptiveButtons(context, tail),
          ],
        );
      },
      child: widget.child,
    );
  }
}
