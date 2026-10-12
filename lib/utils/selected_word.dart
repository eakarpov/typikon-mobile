/// ОДНО СЛОВО ИЗ ВЫДЕЛЕНИЯ — и сравнение написаний без оглядки на правописание.
///
/// Ударение и разбор предлагаются, когда выделено одно слово. Долгое нажатие
/// на телефоне выделяет слово вместе с тем, что к нему прилипло, — запятой,
/// точкой, скобкой, — и отказаться из-за них было бы глупо; а два слова — уже
/// не слово, и спрашивать о них нечего.
library;

import 'accents.dart';

/// Кириллица с расширениями, где лежат ѡ, ѿ, ꙋ, ѯ и прочие буквы ЦСЯ.
final RegExp _cyrillic = RegExp(r"[Ѐ-ԯᲀ-᲏ⷠ-ⷿꙀ-ꚟ]");

/// Буква или надстрочный знак — всё, из чего состоит слово. Дефис внутри
/// слова тоже свой: «ѿ-нюдуже» встречается в наборе.
final RegExp _wordChar = RegExp(r"[\p{L}\p{M}҃-҉ⷠ-ⷿ꙯-꙽-]", unicode: true);

/// Слово из выделения или `null`, если выделено не одно слово.
///
/// Снимаются знаки препинания по краям, а внутри слова не должно остаться
/// ничего, кроме букв и надстрочных знаков. Слово должно быть кириллическим:
/// латинская сноска или число — не повод спрашивать словарь церковнославянского.
String? selectedWord(String? selection) {
  if (selection == null) return null;
  final chars = selection.trim().runes.map(String.fromCharCode).toList();

  var start = 0;
  var end = chars.length;
  while (start < end && !_isWordChar(chars[start], edge: true)) {
    start++;
  }
  while (end > start && !_isWordChar(chars[end - 1], edge: true)) {
    end--;
  }
  if (start == end) return null;

  final word = chars.sublist(start, end);
  if (!word.every((char) => _isWordChar(char))) return null;

  final joined = word.join();
  if (!_cyrillic.hasMatch(joined)) return null;
  return joined;
}

/// Дефис по краю — не часть слова, а перенос или тире, набранное дефисом.
bool _isWordChar(String char, {bool edge = false}) {
  if (edge && char == "-") return false;
  return _wordChar.hasMatch(char);
}

/// Титло и надстрочные буквы: слово под ними — сокращение, «бг҃ъ» за «богъ».
/// Словарь сокращений не знает, и сказать об этом лучше прямо, чем ответить
/// «такого слова нет».
final RegExp _titlo = RegExp(r"[҃꙯ⷠ-ⷿ]");

bool hasTitlo(String word) => _titlo.hasMatch(word);

/// Буквы, которые пишутся по-разному в разных правописаниях, а читаются одинаково.
const Map<String, String> _letters = {
  "і": "и",
  "ї": "и",
  "ѵ": "и",
  "ѷ": "и",
  "ѣ": "е",
  "є": "е",
  "ѥ": "е",
  "ѡ": "о",
  "ѻ": "о",
  "ꙍ": "о",
  "ꙋ": "у",
  "ѹ": "у",
  "ѫ": "у",
  "ꙗ": "я",
  "ѧ": "я",
  "ѳ": "ф",
  "ѯ": "кс",
  "ѱ": "пс",
  "ѕ": "з",
  "ꙁ": "з",
  "ѿ": "от",
};

/// Все надстрочные знаки — придыхание, звательце, камора, ерок.
final RegExp _marks = RegExp(r"[̀-ͯ҃-҉꙯-꙽ⸯ]");

/// Ключ для сравнения написаний: без знаков, строчными, в одной азбуке.
///
/// Словарь пишет «хрісто́съ», а в тексте набрано «Христосъ». Это одно слово,
/// и сравнивать их буква в букву нельзя.
String spellingKey(String word) {
  final bare = stripAccents(word).toLowerCase().replaceAll(_marks, "");
  final buffer = StringBuffer();
  for (final char in bare.runes.map(String.fromCharCode)) {
    buffer.write(_letters[char] ?? char);
  }
  return buffer.toString().replaceAll("оу", "у");
}
