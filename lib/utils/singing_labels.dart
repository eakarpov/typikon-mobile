import '../dto/chant.dart';
import '../dto/incipit.dart';

// Подписи певческого корпуса.
//
// Сервер отдаёт коды — `cu_gr`, `vespers`, `menaion`, — а имён к ним не отдаёт
// вовсе: списка допустимых значений у API нет, их знает только сам корпус.
// Поэтому имена наши, и всякое незнакомое значение показывается **как есть**, а
// не прячется и не подменяется «прочим»: заведут в корпусе новый род песнопения
// — читатель увидит его непереведённым, но увидит.

const Map<String, String> _languages = {
  "cu_gr": "ЦС",
  "ro": "РУМ",
  "grc": "ГРЕЧ",
  "en": "АНГЛ",
  "et": "ЭСТ",
  "ar": "АРАБ",
};

const Map<String, String> _services = {
  "vespers": "вечерня",
  "matins": "утреня",
  "liturgy": "литургия",
  "hours": "часы",
  "compline": "повечерие",
  "midnight": "полунощница",
};

const Map<String, String> _books = {
  "menaion": "Минея",
  "octoechos": "Октоих",
  "triod-postnaya": "Триодь постная",
  "triod-tsvetnaya": "Триодь цветная",
  "obshaya-mineya": "Минея общая",
  "irmologion": "Ирмологий",
};

String languageLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_languages[code] ?? code);

String serviceLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_services[code] ?? code);

String bookLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_books[code] ?? code);

/// Адрес песнопения по частям — от общего к частному.
///
/// Первой идёт память или акафист: читатель ищет «где это поётся», и ответ на
/// это — праздник, а не книга. Книга нужна лишь там, где памяти нет.
List<String> chantAddress(Chant chant) {
  final parts = <String>[];

  final where = chant.memory ?? chant.akathist ?? bookLabel(chant.book);
  if (where.isNotEmpty) parts.add(where);

  final service = serviceLabel(chant.service);
  if (service.isNotEmpty) parts.add(service);

  final position = chant.position;
  if (position != null && position.isNotEmpty) parts.add(position);

  if (chant.tone != null) parts.add("глас ${chant.tone}");
  if (chant.stanza != null) parts.add("строфа ${chant.stanza}");

  return parts;
}

/// То же для вхождения зачина. Отличается песнью канона: у зачина она
/// осмысленна (ирмос первой песни и ирмос третьей — разные зачины), а в выдаче
/// поиска её обычно заслоняет позиция.
List<String> witnessAddress(IncipitWitness witness) {
  final parts = <String>[];

  final where = witness.memory ?? witness.akathist ?? bookLabel(witness.book);
  if (where.isNotEmpty) parts.add(where);

  final service = serviceLabel(witness.service);
  if (service.isNotEmpty) parts.add(service);

  final position = witness.position;
  if (position != null && position.isNotEmpty) parts.add(position);

  if (witness.ode != null) parts.add("песнь ${witness.ode}");
  if (witness.tone != null) parts.add("глас ${witness.tone}");
  if (witness.stanza != null) parts.add("строфа ${witness.stanza}");

  return parts;
}

/// Чем установлено соответствие — словами, а не кодом.
///
/// Разница между «так напечатано в издании» и «совпало место в службе» —
/// единственное, что отличает факт от догадки, и прятать её за общим словом
/// «перевод» нельзя.
String correspondenceLabel(IncipitCorrespondence link) {
  if (link.method == "edition") return "так напечатано в издании";
  if (link.method == "structure") return "совпало место в службе";
  return link.method ?? "";
}

/// Знак службы у памяти корпуса.
///
/// Словарь здесь **не тот**, что в `lib/utils/signs.dart`. Тех знаков семь, они
/// заглавными (`DOXOLOGIC`) и приходят из месяцеслова Типикона; эти — из
/// разметки самих служб корпуса, их больше, и записаны они слугами
/// (`slavoslovie`). Перепутать легко и незаметно: `signGlyph("slavoslovie")`
/// вернёт null, и знак просто не нарисуется, ничего не сломав.
///
/// Поэтому здесь слово, а не глиф: глифов у половины этих знаков нет вовсе.
const Map<String, String> _serviceSigns = {
  // «velikiy» приходит только из Соборника Минеи общей: по строению
  // напечатанной службы великий праздник от бденного не отличить.
  "velikiy": "великий праздник",
  "velikoe-bdenie": "великое бдение",
  "bdenie": "бдение",
  "polieley": "полиелей",
  "slavoslovie": "славословие",
  "shesterichnaya": "шестеричная",
  "bez-znaka": "без знака",
  "alliluynaya": "аллилуйная",
  "alliluinaya-postnaya": "аллилуйная постная",
  "povecherie": "повечерие",
};

String serviceSignLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_serviceSigns[code] ?? code);
