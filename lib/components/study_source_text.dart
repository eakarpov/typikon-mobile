import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../utils/reading_style.dart';
import '../utils/script_convert.dart';

/// A source-to-display map keeps a repeated phrase tied to the selected occurrence.
/// Every displayed boundary points into the original source, before font/script changes.
class StudySourceText extends StatefulWidget {
  final String text, setting;
  final TextScript script;
  final void Function(String quote, int offset) onSelection;
  final void Function(String action) onAction;
  final void Function(int number) onFootnote;
  final String? selectedQuote, prefix;
  final List<Map<String, dynamic>> annotations;
  const StudySourceText({
    super.key,
    required this.text,
    required this.script,
    required this.setting,
    required this.onSelection,
    required this.onAction,
    required this.onFootnote,
    this.annotations = const [],
    this.selectedQuote,
    this.prefix,
  });
  @override
  State<StudySourceText> createState() => _StudySourceTextState();
}

class _StudySourceTextState extends State<StudySourceText> {
  final recognizers = <TapGestureRecognizer>[];
  final boundaries = <int>[];
  int displayedLength = 0;
  @override
  void dispose() {
    for (final r in recognizers) r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in recognizers) r.dispose();
    recognizers.clear();
    boundaries.clear();
    displayedLength = 0;
    final raw = widget.text, spans = <InlineSpan>[];
    final base =
        readingTextStyle(
          context,
          churchSlavonic: widget.script == TextScript.church,
        ).copyWith(
          fontFamily: presentFont(
            widget.script == TextScript.church ? 'Monomakh' : 'OldStandard',
            widget.script,
            widget.setting,
          ),
        );
    bool red = false;
    int? markedStart;
    if (widget.selectedQuote?.isNotEmpty == true) {
      var at = -1;
      while ((at = raw.indexOf(widget.selectedQuote!, at + 1)) != -1) {
        if (widget.prefix == null ||
            raw.substring(0, at).endsWith(widget.prefix!)) {
          markedStart = at;
          break;
        }
      }
    }
    final highlights = <({int start, int end})>[];
    for (final target in widget.annotations) {
      final q = target['quote'] as String? ?? '';
      if (q.isEmpty) continue;
      int at = -1, ordinal = 0;
      while ((at = raw.indexOf(q, at + 1)) != -1) {
        if ((target['prefix'] == null ||
                raw.substring(0, at).endsWith(target['prefix'])) &&
            (target['suffix'] == null ||
                raw.substring(at + q.length).startsWith(target['suffix'])) &&
            (target['occurrence'] == null || ordinal == target['occurrence']))
          highlights.add((start: at, end: at + q.length));
        ordinal++;
      }
    }
    void append(
      String source,
      int sourceStart, {
      TextStyle? style,
      VoidCallback? tap,
      int? sourceEnd,
    }) {
      final display = presentScript(source, widget.script, widget.setting);
      final end = sourceEnd ?? sourceStart + source.length;
      if (display.isEmpty) return;
      // Word boundaries are always exact, including conversions that expand letters.
      final map = List<int>.filled(display.length + 1, sourceStart);
      map[display.length] = end;
      if (sourceEnd == null) {
        for (var j = 0; j <= source.length; j++) {
          final prefix = presentScript(
            source.substring(0, j),
            widget.script,
            widget.setting,
          );
          if (display.startsWith(prefix) && prefix.length <= display.length)
            map[prefix.length] = sourceStart + j;
        }
        var last = sourceStart;
        for (var j = 0; j < map.length; j++) {
          if (map[j] < last) map[j] = last;
          last = map[j];
        }
      }
      if (boundaries.isEmpty)
        boundaries.add(sourceStart);
      else
        boundaries[boundaries.length - 1] = sourceStart;
      boundaries.addAll(map.skip(1));
      displayedLength += display.length;
      TapGestureRecognizer? recognizer;
      if (tap != null) {
        recognizer = TapGestureRecognizer()..onTap = tap;
        recognizers.add(recognizer);
      }
      final marked =
          highlights.any((h) => sourceStart < h.end && end > h.start) ||
          markedStart != null &&
              sourceStart < markedStart + widget.selectedQuote!.length &&
              end > markedStart;
      spans.add(
        TextSpan(
          text: display,
          style:
              (style ??
                      (red
                          ? base.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : base))
                  .copyWith(
                    backgroundColor: marked
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
          recognizer: recognizer,
        ),
      );
    }

    // Markup identifiers are never converted or counted as visible source words.
    final marks = RegExp(
      r'\{(?:st|pl)\|([^}|]+)(?:\|([^}]+))?}|\{(\d+)}|\{k\||}|\*\*|^#{1,6}\s',
      multiLine: true,
    );
    void plain(int start, int end) {
      final part = raw.substring(start, end);
      for (final word in RegExp(r'\S+|\s+').allMatches(part))
        append(word.group(0)!, start + word.start);
    }

    var cursor = 0;
    for (final m in marks.allMatches(raw)) {
      plain(cursor, m.start);
      final token = m.group(0)!;
      if (m.group(3) != null) {
        final number = int.parse(m.group(3)!);
        append(
          '[$number]',
          m.start,
          sourceEnd: m.end,
          style: base.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          tap: () => widget.onFootnote(number),
        );
      } else if (token.startsWith('{st|') || token.startsWith('{pl|')) {
        final id = m.group(1)!, label = m.group(2) ?? id;
        final labelAt = m.group(2) == null
            ? m.start + 4
            : m.start + token.indexOf('|', 4) + 1;
        append(
          label,
          labelAt,
          sourceEnd: m.end - 1,
          style: base.copyWith(color: Theme.of(context).colorScheme.primary),
          tap: () => Navigator.pushNamed(
            context,
            token.startsWith('{st|') ? '/saints' : '/places',
            arguments: id,
          ),
        );
      } else if (token == '{k|') {
        red = true;
      } else if (token == '}') {
        if (red)
          red = false;
        else
          append('}', m.start);
      }
      cursor = m.end;
    }
    plain(cursor, raw.length);
    if (boundaries.isEmpty) boundaries.add(0);
    return SelectableText.rich(
      TextSpan(style: base, children: spans),
      textAlign: readingTextAlign(context),
      onSelectionChanged: (selection, cause) {
        if (selection.isCollapsed) return;
        final start = min(
              selection.start,
              selection.end,
            ).clamp(0, boundaries.length - 1),
            end = max(
              selection.start,
              selection.end,
            ).clamp(0, boundaries.length - 1);
        final a = boundaries[start], b = boundaries[end];
        if (a >= 0 && b > a && b <= raw.length)
          widget.onSelection(raw.substring(a, b), a);
      },
      contextMenuBuilder: (context, editable) =>
          AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editable.contextMenuAnchors,
            buttonItems: [
              ...editable.contextMenuButtonItems,
              for (final (action, title) in [
                ('highlight', 'Выделить'),
                ('note', 'Заметка'),
                ('question', 'Вопрос'),
                ('collection', 'В подборку'),
                ('link', 'Связать'),
                ('word', 'Ударение и разбор'),
              ])
                ContextMenuButtonItem(
                  label: title,
                  onPressed: () {
                    editable.hideToolbar();
                    widget.onAction(action);
                  },
                ),
            ],
          ),
    );
  }
}
