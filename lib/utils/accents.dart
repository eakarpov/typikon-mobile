/// ЗНАКИ УДАРЕНИЯ: снять и вернуться обратно.
///
/// Нужно ради заметок. Заметка привязывается к тексту не смещением, а **точным
/// совпадением строки**: подсветка ищет `text.indexOf(phrase)`. Стоит показать
/// текст с машинными ударениями — и заметка, заведённая по книжному написанию,
/// перестаёт находиться. Ни ошибки, ни следа: подсветка просто исчезает.
///
/// Поэтому сравнивать надо без знаков, а красить по исходной строке — отсюда и
/// карта смещений.
///
/// **Снимаем только ударения**, а не всё надстрочное. Титло, звательце и
/// придыхание принадлежат самому письму и стоят в обеих строках одинаково;
/// трогать их незачем, а сняв — мы сравнивали бы не то, что видим.
library;

/// Оксия, вария, камора — три знака, которыми ставится ударение.
const int _oxia = 0x0301;
const int _varia = 0x0300;
const int _kamora = 0x0311;

/// Готовые буквы со знаком: в церковнославянском наборе они встречаются наравне
/// с разложенными, и одна и та же строка бывает записана и так и так.
const Map<int, int> _precomposed = <int, int>{
  0x0450: 0x0435, // ѐ → е
  0x045D: 0x0438, // ѝ → и
};

bool _isAccent(int code) =>
    code == _oxia || code == _varia || code == _kamora;

/// Строка без знаков ударения.
String stripAccents(String text) => unaccent(text).text;

/// Строка без знаков и карта обратно.
class Unaccented {
  /// Текст без знаков ударения.
  final String text;

  /// Где каждый знак [text] стоял в исходной строке. Длина на единицу больше
  /// длины [text]: последний элемент — конец исходной строки, чтобы отрезок,
  /// доходящий до её края, было чем закрыть.
  final List<int> offsets;

  const Unaccented(this.text, this.offsets);

  /// Отрезок исходной строки, отвечающий отрезку [start]..[end] в [text].
  ///
  /// Конец берётся по началу СЛЕДУЮЩЕЙ буквы: знаки ударения стоят после своей
  /// буквы, и отрезок, кончившийся на ней самой, оставил бы знак снаружи.
  (int, int) sourceRange(int start, int end) => (offsets[start], offsets[end]);
}

Unaccented unaccent(String text) {
  final buffer = StringBuffer();
  final offsets = <int>[];

  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (_isAccent(code)) continue;

    offsets.add(i);
    buffer.writeCharCode(_precomposed[code] ?? code);
  }
  offsets.add(text.length);

  return Unaccented(buffer.toString(), offsets);
}

/// Где в [text] стоит [phrase], если не считать ударений.
///
/// Возвращает отрезок ИСХОДНОЙ строки или `null`, если не нашлось. `from` —
/// откуда искать, в смещениях исходной строки.
(int, int)? findIgnoringAccents(String text, String phrase, [int from = 0]) {
  if (phrase.isEmpty) return null;

  final haystack = unaccent(text);
  final needle = stripAccents(phrase);
  if (needle.isEmpty) return null;

  // `from` дан в исходных смещениях, а искать надо в снятых: находим первую
  // снятую позицию, которая исходной не раньше.
  var start = 0;
  while (start < haystack.text.length && haystack.offsets[start] < from) {
    start++;
  }

  final at = haystack.text.indexOf(needle, start);
  if (at == -1) return null;

  return haystack.sourceRange(at, at + needle.length);
}
