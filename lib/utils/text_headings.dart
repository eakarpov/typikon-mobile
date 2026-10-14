/// ОГЛАВЛЕНИЕ ВНУТРИ ОДНОГО ДЛИННОГО ТЕКСТА.
///
/// Границы глав в корпусе стоят по-разному, и детектор опирается только на
/// формы, увиденные в самих данных (разведка по API, октябрь 2026):
///
///  * абзац целиком — маркер в квадратных скобках: `[Среда]`, `[Среда:]`,
///    `[Статия 3]`, в том числе с незакрытой скобкой `[Чу́до ...` — так
///    наборщик оставил одну из меток в «Житии Варлаама»;
///  * маркер в квадратных скобках в начале абзаца, а после него — перевод
///    строки: `[Статія́ 2-я въ четверто́къ ...]\nПла́чущися же ...` в «Житии
///    Марии Египетской»;
///  * короткий однострочный абзац-заголовок главы жития без конечной точки:
///    «О рожде́нии блаже́ннаго Варлаа́ма», «Чу́до свята́го о ры́бах», «И́но
///    чу́до ...», «О слѣпо́м»;
///  * летописный год: абзац, начинающийся с «В лѣто <число>» — заголовком
///    берётся первая фраза, если она короткая («В лѣто 6360, индикта 15,
///    наченшю Михаилу цесарьствовати»), иначе одно «В лѣто 6366».
///
/// У Пролога, Великих Четьих-Миней и прочих помесячных книг день — это
/// отдельный текст: внутри одного текста дни ничем не размечены, и такие
/// тексты детектор честно оставляет без оглавления.
library;

import 'accents.dart';

/// Глава внутри текста: номер абзаца-заголовка и подпись для оглавления.
class TextHeading {
  final int paragraphIndex;
  final String title;

  const TextHeading(this.paragraphIndex, this.title);
}

/// Самый длинный заголовок, который ещё оглавление: сверх него это уже не
/// подпись главы, а цитата.
const int maxHeadingLength = 80;

/// Сколько знаков от начала летописного абзаца берётся в заголовок.
const int chronicleTitleLength = 60;

/// Заголовки по списку абзацев (тому же сплиту `content.split("\n\n")`, что
/// рисует страница). Возвращается в порядке следования абзацев.
List<TextHeading> findTextHeadings(List<String> paragraphs) {
  final headings = <TextHeading>[];

  for (var index = 0; index < paragraphs.length; index++) {
    final title = _headingTitle(paragraphs[index]);
    if (title != null) headings.add(TextHeading(index, title));
  }

  return headings;
}

/// Подпись главы, если абзац ей является, иначе `null`.
String? _headingTitle(String paragraph) {
  final trimmed = paragraph.trim();
  if (trimmed.isEmpty) return null;

  final bracket = _bracketTitle(trimmed);
  if (bracket != null) return bracket;

  final chronicle = _chronicleTitle(trimmed);
  if (chronicle != null) return chronicle;

  return _shortTitle(trimmed);
}

/// Абзац целиком или с начала — маркер в квадратных скобках. Скобки в подпись
/// не берутся, только то, что между ними.
String? _bracketTitle(String trimmed) {
  if (!trimmed.startsWith("[")) return null;

  final closing = trimmed.indexOf("]");
  if (closing == -1) {
    // Незакрытая скобка: метка всего абзаца, если он короткий.
    final inner = trimmed.substring(1).trim();
    return inner.length <= maxHeadingLength ? inner : null;
  }

  final inner = trimmed.substring(1, closing).trim();
  if (inner.isEmpty) return null;
  final after = trimmed.substring(closing + 1);
  final rest = after.trimLeft();
  // Целиком — всегда заголовок; лежит в начале, а текст пошёл со следующей
  // строки, — тоже: `[Статія́ 2-я ...]\nПла́чущися же ...`. Проверка по
  // необрезанному хвосту: `trimLeft` съел бы и сам перевод строки.
  if (rest.isEmpty || after.startsWith("\n")) {
    return inner.length <= maxHeadingLength ? inner : null;
  }
  return null;
}

/// Летописный год: «В лѣто 6366. Михаилъ цесарь ...» или просто «В лѣто 6361.»
/// Заголовок — первая фраза до точки, пока она умещается в короткую подпись.
String? _chronicleTitle(String trimmed) {
  final plain = stripAccents(trimmed).toLowerCase();
  const prefix = "в лѣто ";
  if (!plain.startsWith(prefix)) return null;
  if (plain.length <= prefix.length || !_isDigit(plain[prefix.length])) {
    return null;
  }

  var end = trimmed.length < chronicleTitleLength ? trimmed.length : chronicleTitleLength;
  final dot = trimmed.indexOf(".");
  if (dot != -1 && dot < end) end = dot;
  final newline = trimmed.indexOf("\n");
  if (newline != -1 && newline < end) end = newline;
  if (end < trimmed.length) {
    // Обрезка идёт посередине текста — отступаем к границе слова: подпись
    // «наченшю Михаилу цесар» хуже короткой.
    final lastSpace = trimmed.lastIndexOf(" ", end);
    if (lastSpace > prefix.length) end = lastSpace;
  }

  var title = trimmed.substring(0, end).trim();
  // Хвост оборван на запятой — обрыв на полуслове хуже короткого заголовка.
  while (title.endsWith(",") || title.endsWith(" ")) {
    title = title.substring(0, title.length - 1).trim();
  }
  return title.isEmpty ? null : title;
}

/// Короткий однострочный абзац-заголовок главы жития: «О рожде́нии ...»,
/// «Чу́до о ры́бах», «И́но чу́до ...». Без конечной точки: предложение —
/// это уже текст главы, а не её название.
String? _shortTitle(String trimmed) {
  if (trimmed.length > maxHeadingLength) return null;
  if (trimmed.contains("\n")) return null;
  if (trimmed.contains("{")) return null;
  final last = trimmed[trimmed.length - 1];
  if (last == '.' || last == '!' || last == '?' || last == ';' || last == '»') {
    return null;
  }

  final plain = stripAccents(trimmed).toLowerCase();
  final isChapterTitle = plain.startsWith("о ") ||
      plain.startsWith("чудо") ||
      plain.startsWith("ино");
  return isChapterTitle ? trimmed : null;
}

bool _isDigit(String char) => char.compareTo("0") >= 0 && char.compareTo("9") <= 0;
