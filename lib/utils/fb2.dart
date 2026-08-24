// Сборка fb2 из текста чтения.
//
// Раньше файл склеивался прямо в обработчике кнопки, без экранирования: любой
// `&` или `<` в тексте делал xml невалидным, и читалка отказывалась открывать
// файл. Заодно весь текст уезжал одним абзацем, автор был "No author", дата
// зашита в код, а язык объявлен английским.

/// Экранирование для текстовых узлов xml. Амперсанд обязан идти первым, иначе
/// он повторно экранирует уже подставленные сущности.
String escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

/// Убирает разметку, осмысленную только внутри приложения: `{k|слово}` —
/// киноварная выделенная фраза (в файл уходит сама фраза), `{12}` — ссылка на
/// сноску (в файле её не на что нажимать).
String stripReadingMarkup(String value) {
  return value
      .replaceAllMapped(RegExp(r"\{k\|(.+?)}"), (m) => m.group(1) ?? "")
      .replaceAll(RegExp(r"\{\d+}"), "");
}

/// Границы абзацев — те же, что использует страница чтения (`\n\n`). Часть
/// текстов в базе разделена иначе, из-за чего схлопывается в один абзац; это
/// известная проблема данных, и чинится она на бекенде, а не здесь — иначе
/// экспорт и экран разошлись бы между собой.
List<String> splitParagraphs(String content) {
  return content
      .split("\n\n")
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Имя файла из названия текста: раньше все выгрузки назывались одинаково
/// ("Из уставных чтений"), и в папке загрузок копились безымянные дубли.
String fb2FileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), " ")
      .replaceAll(RegExp(r"\s+"), " ")
      .trim();
  if (cleaned.isEmpty) return "Из уставных чтений";
  return cleaned.length > 80 ? cleaned.substring(0, 80).trim() : cleaned;
}

String buildFb2({
  required String id,
  required String name,
  required String? author,
  required String content,
  required DateTime now,
}) {
  final title = escapeXml(name);
  final dateValue = "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}";
  final dateLabel = "${_twoDigits(now.day)}.${_twoDigits(now.month)}.${now.year}";

  final authorNode = (author != null && author.trim().isNotEmpty)
      ? "<author><nickname>${escapeXml(author.trim())}</nickname></author>"
      : "<author><nickname>Автор не указан</nickname></author>";

  final paragraphs = splitParagraphs(stripReadingMarkup(content))
      .map((p) => "    <p>${escapeXml(p)}</p>")
      .join("\n");

  return """<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
<description>
  <title-info>
    <genre>religion</genre>
    $authorNode
    <book-title>$title</book-title>
    <lang>ru</lang>
  </title-info>
  <document-info>
    <author><nickname>typikon.su</nickname></author>
    <program-used>Уставные чтения</program-used>
    <date value="$dateValue">$dateLabel</date>
    <id>${escapeXml(id)}</id>
    <version>1.0</version>
  </document-info>
</description>
<body>
  <section>
    <title><p>$title</p></title>
$paragraphs
  </section>
</body>
</FictionBook>
""";
}
