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

// --- Каноны, акафисты, молитвы -------------------------------------------------
//
// Те же правила, что и выше: имена наши, коды сервера, незнакомое показывается
// как есть. Два кода подписаны здесь, а на сайте нет, — `inoe` и `weekday`; там
// они выпадают латиницей, и сказать об этом вебу стоит.

const Map<String, String> _units = {
  "stichera": "стихира",
  "sedalen": "седален",
  "troparion": "тропарь",
  "irmos": "ирмос",
  "kontakion": "кондак",
  "ikos": "икос",
  "svetilen": "светилен",
  "velichanie": "величание",
  "prokimen": "прокимен",
  "paremiya": "паремия",
  "apostol": "Апостол",
  "evangelie": "Евангелие",
  "ipakoi": "ипакои",
  "verse": "стих",
  "molitva": "молитва",
};

String unitLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_units[code] ?? code);

/// Чем строка помечена в книге: богородичен, троичен, мученичен.
const Map<String, String> _markers = {
  "bogorodicen": "богородичен",
  "krestobogorodicen": "крестобогородичен",
  "troicen": "троичен",
  "mucenicen": "мученичен",
  "zaupokoiny": "заупокойный",
  "prazdnika": "праздника",
};

String markerLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_markers[code] ?? code);

const Map<String, String> _placements = {
  "slava": "Слава",
  "i-nyne": "И ныне",
  "slava-i-nyne": "Слава, и ныне",
};

String placementLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_placements[code] ?? code);

/// Роль канона в службе. Октоих объявляет её сам, и устав зовёт канон по имени,
/// а не по порядку печати.
const Map<String, String> _canonRoles = {
  "voskresny": "воскресный",
  "krestovoskresny": "крестовоскресный",
  "bogorodichen": "Богородицы",
  // На сайте не подписан и выпадает латиницей.
  "weekday": "седмичный",
};

String canonRoleLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_canonRoles[code] ?? code);

/// Кому акафист.
///
/// «Пред иконой» отдельно от «Богородице» намеренно: акафист пред иконой
/// обращён к иконе, и свести их в одно значило бы соврать в одном из двух.
const Map<String, String> _subjectKinds = {
  "gospod": "Господу",
  "bogorodica": "Богородице",
  "ikona": "пред иконой",
  "prazdnik": "празднику",
  "svyatoy": "святому",
  // Не отговорка, а то, что стоит в источнике: раздел «Акафисты иные» держит
  // Кресту, Ангелам, ко Причащению, о упокоении и покаянный. Таких шестнадцать,
  // и на сайте они показываются словом `inoe`.
  "inoe": "иное",
};

String subjectKindLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_subjectKinds[code] ?? code);

/// Чем акафист является уставу.
///
/// **Различать обязательно.** Уставом положен ровно один — Великий; остальные
/// тысяча сто один к общественному богослужению не назначены и в сборку служб
/// не идут. Перечень без этой пометы обещает читателю обратное.
const Map<String, String> _akathistStatuses = {
  "ustavny": "положен уставом",
  "odobrenny": "одобрен к употреблению",
  "chastny": "частное сочинение",
};

String akathistStatusLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_akathistStatuses[code] ?? code);

const Map<String, String> _prayerKinds = {
  "memory": "при памяти",
  "akathist": "при акафисте",
  "canon": "при каноне",
};

String prayerKindLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_prayerKinds[code] ?? code);

/// Адрес строфы акафиста: «икос 4», «кондак 12», «проимий 1».
///
/// Проимий подписывается родом, а не жанром: по форме он кондак, но кондаки
/// акростиха нумерованы своим счётом, и «кондак 1» рядом с «кондак 2» читалось
/// бы как соседние строфы, тогда как это разные ряды.
String stanzaLabel(String? unit, int? stanza, String? kind) {
  if (stanza == null) return "";
  if (kind == "prooimion") return "проимий $stanza";
  final name = unitLabel(unit);
  return name.isEmpty ? "" : "$name $stanza";
}

/// Где в книге стоит память: «11 мая», «глас 1, воскресенье», «−15 от Пасхи».
///
/// У каждой книги своя координата, и общей нет: Минея адресует числом
/// месяцеслова, Октоих — гласом и днём седмицы, Триоди — расстоянием от Пасхи.
/// Поэтому не одно поле, а то из них, какое у этой книги непусто.
String memoryAddress({
  String? book,
  int? month,
  int? day,
  int? paschaOffset,
  String? weekday,
  int? memoryTone,
}) {
  if (book == "menaion" && month != null && day != null) {
    return "$day ${_monthOf(month)}";
  }
  if (book == "octoechos") {
    final parts = <String>[
      if (memoryTone != null) "глас $memoryTone",
      if (weekday != null && weekday.isNotEmpty) _weekdayLabel(weekday),
    ].where((part) => part.isNotEmpty).toList();
    return parts.join(", ");
  }
  if (paschaOffset != null) {
    // Знак сохраняем: до Пасхи и после неё — разные половины года.
    return "${paschaOffset > 0 ? "+" : "−"}${paschaOffset.abs()} от Пасхи";
  }
  return "";
}

const List<String> _months = [
  "", "января", "февраля", "марта", "апреля", "мая", "июня",
  "июля", "августа", "сентября", "октября", "ноября", "декабря",
];

String _monthOf(int month) => month >= 1 && month <= 12 ? _months[month] : "";

const Map<String, String> _weekdays = {
  "voskresenie": "воскресенье",
  "ponedelnik": "понедельник",
  "vtornik": "вторник",
  "sreda": "среда",
  "chetverg": "четверг",
  "pyatnica": "пятница",
  "subbota": "суббота",
};

String _weekdayLabel(String code) => _weekdays[code] ?? code;
