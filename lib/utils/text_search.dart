/// ПОИСК ВНУТРИ ОТКРЫТОГО ТЕКСТА.
///
/// Совпадения ищутся тем же приёмом, что подсветка заметок: сравнение без
/// знаков ударения, а диапазоны возвращаются в ИСХОДНОЙ строке — красить и
/// прокручивать надо то, что видит читатель. Регистр не различается: ищется
/// по нижнему регистру, а смещения переносятся обратно (приведение регистра в
/// корпусе посимвольное и длину строки не меняет).
library;

import 'accents.dart';

/// Сколько совпадений максимум собирается по всему тексту: сверх этого
/// подсветка и счётчик останавливаются. Длинное чтение и короткий запрос давали
/// бы тысячи вхождений, и страница перерисовывалась бы с ними всеми.
const int searchMatchLimit = 500;

/// Минимальная длина запроса, с которой поиск имеет смысл: одиночная буква
/// находит слишком много, чтобы по этому листать.
const int minSearchQueryLength = 2;

/// Диапазон совпадения в исходной строке абзаца: [start, end).
typedef TextRange = (int, int);

/// Где в абзацах стоит запрос: индекс абзаца → диапазоны в его исходной
/// строке, по возрастанию start. Абзацы без совпадений в карту не попадают.
Map<int, List<TextRange>> searchParagraphs(
  List<String> paragraphs,
  String query,
) {
  final trimmed = query.trim();
  if (trimmed.length < minSearchQueryLength) return {};

  // Совпадение должно держаться на запросе без ударений: «Господь» находит и
  // «Госпо́дь». Сам запрос снимаем до проверки длины, чтобы один лишь знак
  // ударения не считался вторым знаком осмысленного запроса.
  if (stripAccents(trimmed).length < minSearchQueryLength) return {};

  final matches = <int, List<TextRange>>{};
  var total = 0;

  // Регистр снимаем обеими копиями: искать по «господу», чтобы находить и
  // «Господь». findIgnoringAccents вернёт отрезок именно этой строки, а она
  // длиной с исходную — диапазон годится и для неё.
  final loweredQuery = trimmed.toLowerCase();

  for (var index = 0; index < paragraphs.length && total < searchMatchLimit; index++) {
    final text = paragraphs[index];
    if (text.isEmpty) continue;

    final lowered = text.toLowerCase();
    var from = 0;
    final ranges = <TextRange>[];

    while (total < searchMatchLimit) {
      final found = findIgnoringAccents(lowered, loweredQuery, from);
      if (found == null) break;
      ranges.add(found);
      from = found.$2;
      total++;
    }

    if (ranges.isNotEmpty) matches[index] = ranges;
  }

  return matches;
}

/// Все диапазоны карты подряд, в порядке абзацев и позиций в них — тот
/// плоский список, по которому листают стрелки «N из M».
List<TextRange> flattenSearchMatches(Map<int, List<TextRange>> byParagraph) {
  return byParagraph.values.expand((ranges) => ranges).toList();
}
