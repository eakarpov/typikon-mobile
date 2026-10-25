import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:typikon/dto/user_note.dart';
import 'package:typikon/utils/accents.dart';
import 'package:typikon/utils/text_search.dart';

/// Разбивает [text] на TextSpan'ы, подсвечивая вхождения phrase каждой
/// заметки из [notes] (мягкий жёлтый фон — не меняет цвет/шрифт самого
/// текста, чтобы не сливаться, но и не перебивать чтение) с тапом,
/// открывающим заметку. Если заметок для этого текста нет — обычный
/// TextSpan(text: ...), как было до этой фичи.
///
/// [searchMatches] подсвечиваются вторым слоем тем же приёмом, а [activeMatch]
/// — совпадение, на котором стоит листание, — контрастнее. Заметки при
/// перекрытии важнее: они кликабельны, и кусок поиска, попавший на заметку,
/// отрезается, а не закрывает её фоном.
List<InlineSpan> buildHighlightedSpans(
  String text,
  TextStyle style,
  List<UserNote> notes,
  void Function(UserNote note) onTapNote, {
  List<TextRange> searchMatches = const [],
  TextRange? activeMatch,
  bool nightPalette = false,
}) {
  final hasNotes = notes.isNotEmpty;
  final hasSearch = searchMatches.isNotEmpty;
  if (!hasNotes && !hasSearch) {
    return [TextSpan(text: text, style: style)];
  }

  // Подложка подбирается под цвет самого текста, а не под тему: цвет чтений
  // может быть и выбран пользователем вручную. Светлый текст (тёмная тема) на
  // бледно-жёлтом не читается, поэтому для него берём тёмную янтарную подложку.
  final textColor = style.color;
  final isLightText = textColor == null || textColor.computeLuminance() > 0.5;
  final highlightStyle = style.copyWith(
    backgroundColor: nightPalette
        ? const Color(0xFF3D1915)
        : isLightText
        ? const Color(0xFF5A4A00)
        : const Color(0xFFFFF3B0),
  );
  // Подложка совпадений поиска — по тому же правилу светлоты, но не желтая,
  // чтобы два слоя отличались; текущее совпадение — оранжевым, заметным.
  final searchStyle = style.copyWith(
    backgroundColor: nightPalette
        ? const Color(0xFF29100F)
        : isLightText
        ? const Color(0xFF3D4A63)
        : const Color(0xFFDFE9F5),
  );
  final activeSearchStyle = style.copyWith(
    backgroundColor: nightPalette
        ? const Color(0xFF62251D)
        : isLightText
        ? const Color(0xFFE65100)
        : const Color(0xFFFFB74D),
  );

  // Заметки, как прежде: ищем без оглядки на ударения, а красим по исходной
  // строке. Диапазоны не пересекаются: курсор уходит за конец найденного, и
  // следующий поиск начинается уже за ним.
  final noteSegments = <_Segment>[];
  if (hasNotes) {
    var cursor = 0;
    while (cursor < text.length) {
      int bestStart = -1;
      int bestEnd = -1;
      UserNote? bestNote;

      for (final note in notes) {
        final found = findIgnoringAccents(text, note.selection.phrase, cursor);
        if (found == null) continue;
        if (bestStart == -1 || found.$1 < bestStart) {
          bestStart = found.$1;
          bestEnd = found.$2;
          bestNote = note;
        }
      }

      if (bestNote == null) break;
      noteSegments.add(_Segment(bestStart, bestEnd, note: bestNote));
      cursor = bestEnd;
    }
  }

  // Совпадения поиска вычитаются из занятых заметками мест: кусок, легший на
  // заметку, не рисуем вовсе — иначе его фон закрыл бы кликабельный жёлтый.
  final searchSegments = <_Segment>[];
  for (final range in searchMatches) {
    var pieces = [range];
    for (final noteSegment in noteSegments) {
      pieces = pieces
          .expand((piece) => _subtract(piece, noteSegment.range))
          .toList();
    }
    for (final piece in pieces) {
      final active =
          activeMatch != null &&
          piece.$1 < activeMatch.$2 &&
          activeMatch.$1 < piece.$2;
      searchSegments.add(_Segment(piece.$1, piece.$2, active: active));
    }
  }

  final segments = [...noteSegments, ...searchSegments]
    ..sort((a, b) => a.start.compareTo(b.start));

  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final segment in segments) {
    if (segment.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, segment.start), style: style),
      );
    }
    if (segment.note != null) {
      final note = segment.note!;
      spans.add(
        TextSpan(
          // Показываем то, что стоит в тексте, а не то, что записано в заметке:
          // виды различаются знаками, и подставив написание заметки, мы нарисовали
          // бы посреди книги слово из другого вида.
          text: text.substring(segment.start, segment.end),
          style: highlightStyle,
          recognizer: TapGestureRecognizer()..onTap = () => onTapNote(note),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: text.substring(segment.start, segment.end),
          style: segment.active ? activeSearchStyle : searchStyle,
        ),
      );
    }
    cursor = segment.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: style));
  }

  return spans;
}

/// Часть [piece] вне [occupied]: непересекающиеся остатки слева и справа.
List<TextRange> _subtract(TextRange piece, TextRange occupied) {
  final result = <TextRange>[];
  if (piece.$1 < occupied.$1) {
    final end = piece.$2 < occupied.$1 ? piece.$2 : occupied.$1;
    result.add((piece.$1, end));
  }
  if (occupied.$2 < piece.$2) {
    final start = piece.$1 > occupied.$2 ? piece.$1 : occupied.$2;
    result.add((start, piece.$2));
  }
  return result;
}

class _Segment {
  final int start;
  final int end;
  final UserNote? note;
  final bool active;

  const _Segment(this.start, this.end, {this.note, this.active = false});

  TextRange get range => (start, end);
}
