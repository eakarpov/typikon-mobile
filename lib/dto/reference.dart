// Справочные разделы: именины, хронология, словарь.
//
// Три разных предмета, но одна общая черта — все три отвечают не «вот текст», а
// «вот разбор», и у каждого есть чем этот разбор подпереть: у именин признак
// догадки, у хронологии перечень непрочтённого, у словаря пометка «выписано или
// порождено». Ни одну из трёх подпорок терять нельзя.

int? _asIntOrNull(dynamic value) => value is int ? value : int.tryParse("$value");

String _asString(dynamic value) => value is String ? value : "";

String? _asStringOrNull(dynamic value) =>
    value is String && value.isNotEmpty ? value : null;

List<String> _strings(dynamic list) => list is List
    ? list.whereType<String>().where((item) => item.isNotEmpty).toList()
    : const [];

// --- Именины -----------------------------------------------------------------

/// Строка указателя имён.
class NameIndexEntry {
  final String key;
  final String name;
  final int count;

  const NameIndexEntry({required this.key, required this.name, required this.count});

  factory NameIndexEntry.fromJson(Map<String, dynamic> json) => NameIndexEntry(
        key: _asString(json["key"]),
        name: _asString(json["name"]),
        count: _asIntOrNull(json["count"]) ?? 0,
      );
}

class NamedSaint {
  final String slug;
  final String name;

  /// `guess` — имя вынуто из соборной памяти, где перечень идёт вперемешку.
  /// Показывать это обязательно: речь о том, когда человеку праздновать.
  final String confidence;

  const NamedSaint({required this.slug, required this.name, required this.confidence});

  bool get isGuess => confidence == "guess";

  factory NamedSaint.fromJson(Map<String, dynamic> json) => NamedSaint(
        slug: _asString(json["slug"]),
        name: _asString(json["name"]),
        confidence: _asString(json["confidence"]).isEmpty ? "sure" : _asString(json["confidence"]),
      );
}

class NameMemory {
  /// Гражданская дата выбранного года.
  final String date;

  /// Подвижная память в другой год придётся на другое число.
  final bool movable;

  final NamedSaint saint;

  const NameMemory({required this.date, required this.movable, required this.saint});

  static NameMemory? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final saint = map["saint"];
    if (saint is! Map) return null;
    return NameMemory(
      date: _asString(map["date"]),
      movable: map["movable"] == true,
      saint: NamedSaint.fromJson(Map<String, dynamic>.from(saint)),
    );
  }
}

class NameEntry {
  final String key;
  final String name;
  final int year;
  final List<NamedSaint> saints;
  final List<NameMemory> memories;

  /// Именины по дню рождения — только если день рождения назвали.
  final NameMemory? nameDay;

  /// Чем является правило именин. Приходит от сервера, а не сочиняется здесь:
  /// оговорка обязана ехать вместе с датой.
  final String caveat;

  const NameEntry({
    required this.key,
    required this.name,
    required this.year,
    required this.saints,
    required this.memories,
    required this.caveat,
    this.nameDay,
  });

  factory NameEntry.fromJson(Map<String, dynamic> json) {
    final saints = json["saints"];
    final memories = json["memories"];
    return NameEntry(
      key: _asString(json["key"]),
      name: _asString(json["name"]),
      year: _asIntOrNull(json["year"]) ?? DateTime.now().year,
      saints: saints is List
          ? saints
              .whereType<Map>()
              .map((row) => NamedSaint.fromJson(Map<String, dynamic>.from(row)))
              .toList()
          : const [],
      memories: memories is List
          ? memories.map(NameMemory.fromJson).whereType<NameMemory>().toList()
          : const [],
      nameDay: NameMemory.fromJson(json["nameDay"]),
      caveat: _asString(json["caveat"]),
    );
  }
}

// --- Хронология ---------------------------------------------------------------

class ChronologyDay {
  /// Как записано в источнике — юлианским счётом.
  final String julian;

  /// И то же число нынешним календарём.
  final String civil;
  final String weekday;

  const ChronologyDay({required this.julian, required this.civil, required this.weekday});

  static ChronologyDay? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    return ChronologyDay(
      julian: _asString(map["julian"]),
      civil: _asString(map["civil"]),
      weekday: _asString(map["weekday"]),
    );
  }
}

class YearMarks {
  final int indikt;
  final int krugSolntsu;
  final int krugLune;
  final int vrutseleto;
  final String vrutseletoLetter;
  final int osnovanie;
  final int epakta;
  final String klyuchGranits;
  final bool vysokosniy;
  final ChronologyDay? pascha;

  const YearMarks({
    required this.indikt,
    required this.krugSolntsu,
    required this.krugLune,
    required this.vrutseleto,
    required this.vrutseletoLetter,
    required this.osnovanie,
    required this.epakta,
    required this.klyuchGranits,
    required this.vysokosniy,
    this.pascha,
  });

  factory YearMarks.fromJson(Map<String, dynamic> json) => YearMarks(
        indikt: _asIntOrNull(json["indikt"]) ?? 0,
        krugSolntsu: _asIntOrNull(json["krugSolntsu"]) ?? 0,
        krugLune: _asIntOrNull(json["krugLune"]) ?? 0,
        vrutseleto: _asIntOrNull(json["vrutseleto"]) ?? 0,
        vrutseletoLetter: _asString(json["vrutseletoLetter"]),
        osnovanie: _asIntOrNull(json["osnovanie"]) ?? 0,
        epakta: _asIntOrNull(json["epakta"]) ?? 0,
        klyuchGranits: _asString(json["klyuchGranits"]),
        vysokosniy: json["vysokosniy"] == true,
        pascha: ChronologyDay.fromJson(json["pascha"]),
      );
}

class ChronologyCandidate {
  final String label;
  final int? leto;
  final YearMarks marks;
  final ChronologyDay? day;

  const ChronologyCandidate({
    required this.label,
    required this.marks,
    this.leto,
    this.day,
  });

  factory ChronologyCandidate.fromJson(Map<String, dynamic> json) {
    final marks = json["marks"];
    return ChronologyCandidate(
      label: _asString(json["label"]),
      leto: _asIntOrNull(json["leto"]),
      marks: YearMarks.fromJson(
          marks is Map ? Map<String, dynamic>.from(marks) : const {}),
      day: ChronologyDay.fromJson(json["day"]),
    );
  }
}

/// Поправка: какое чтение потребовалось бы на месте противоречащего условия.
class ChronologyFix {
  final String label;
  final String stated;
  final String needed;
  final ChronologyCandidate candidate;

  const ChronologyFix({
    required this.label,
    required this.stated,
    required this.needed,
    required this.candidate,
  });

  static ChronologyFix? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final candidate = map["candidate"];
    if (candidate is! Map) return null;
    return ChronologyFix(
      label: _asString(map["label"]),
      stated: "${map["stated"] ?? ""}",
      needed: "${map["needed"] ?? ""}",
      candidate: ChronologyCandidate.fromJson(Map<String, dynamic>.from(candidate)),
    );
  }
}

class ChronologyAnswer {
  /// `none`, `one`, `same-day` или `many` — и словами то же самое.
  final String kind;
  final String text;

  final int considered;
  final List<String> applied;

  /// Условия, которые назвали, но прочесть не удалось: в переборе они не
  /// участвовали. Молчать об этом нельзя — ответ выглядел бы подтверждённым
  /// тем, чего в нём нет.
  final List<String> ignored;

  final List<ChronologyCandidate> survivors;
  final List<ChronologyFix> fixes;

  const ChronologyAnswer({
    required this.kind,
    required this.text,
    required this.considered,
    required this.applied,
    required this.ignored,
    required this.survivors,
    required this.fixes,
  });

  factory ChronologyAnswer.fromJson(Map<String, dynamic> json) {
    final verdict = json["verdict"];
    final map = verdict is Map ? Map<String, dynamic>.from(verdict) : const {};
    final survivors = json["survivors"];
    final fixes = json["fixes"];

    return ChronologyAnswer(
      kind: _asString(map["kind"]),
      text: _asString(map["text"]),
      considered: _asIntOrNull(json["considered"]) ?? 0,
      applied: _strings(json["applied"]),
      ignored: _strings(json["ignored"]),
      survivors: survivors is List
          ? survivors
              .whereType<Map>()
              .map((row) => ChronologyCandidate.fromJson(Map<String, dynamic>.from(row)))
              .toList()
          : const [],
      fixes: fixes is List
          ? fixes.map(ChronologyFix.fromJson).whereType<ChronologyFix>().toList()
          : const [],
    );
  }
}

// --- Словарь ------------------------------------------------------------------

class LexemeSummary {
  final String id;
  final String name;

  /// Пометы словаря как есть — «S,m,anim».
  final String properties;
  final String pos;
  final String scheme;

  const LexemeSummary({
    required this.id,
    required this.name,
    required this.properties,
    required this.pos,
    required this.scheme,
  });

  factory LexemeSummary.fromJson(Map<String, dynamic> json) => LexemeSummary(
        id: _asString(json["id"]),
        name: _asString(json["name"]),
        properties: _asString(json["properties"]),
        pos: _asString(json["pos"]),
        scheme: _asString(json["scheme"]),
      );
}

class LexemeForm {
  final String value;

  /// Выписана в словаре или порождена по таблице склонения. Разница между
  /// фактом и выводом, и схлопывать её не следует.
  final bool stored;

  const LexemeForm({required this.value, required this.stored});

  factory LexemeForm.fromJson(Map<String, dynamic> json) => LexemeForm(
        value: _asString(json["value"]),
        stored: json["stored"] == true,
      );
}

class LexemeSlot {
  /// Грамматический адрес ячейки: `sgNom`, `plGen`, `aorPl3`, `partPastPass`.
  final String slot;
  final List<LexemeForm> forms;

  const LexemeSlot({required this.slot, required this.forms});

  factory LexemeSlot.fromJson(Map<String, dynamic> json) {
    final forms = json["forms"];
    return LexemeSlot(
      slot: _asString(json["slot"]),
      forms: forms is List
          ? forms
              .whereType<Map>()
              .map((row) => LexemeForm.fromJson(Map<String, dynamic>.from(row)))
              .toList()
          : const [],
    );
  }
}

class LexemeParadigm {
  /// `noun`, `adjective-brev`, `adjective-plen`, `verb`, `participle-*`.
  final String kind;
  final String? title;
  final String? base;
  final List<LexemeSlot> slots;

  const LexemeParadigm({required this.kind, required this.slots, this.title, this.base});

  factory LexemeParadigm.fromJson(Map<String, dynamic> json) {
    final slots = json["slots"];
    return LexemeParadigm(
      kind: _asString(json["kind"]),
      title: _asStringOrNull(json["title"]),
      base: _asStringOrNull(json["base"]),
      slots: slots is List
          ? slots
              .whereType<Map>()
              .map((row) => LexemeSlot.fromJson(Map<String, dynamic>.from(row)))
              .toList()
          : const [],
    );
  }
}

class Lexeme {
  final String id;
  final String name;
  final String scheme;
  final String pos;
  final List<String> properties;

  /// Есть ли для схемы таблица склонения. Нет — парадигмы не будет вовсе, и
  /// остаются одни выписанные формы. Сказать об этом надо: пустая таблица иначе
  /// читается как «слово не склоняется».
  final bool known;

  final List<LexemeParadigm> paradigms;

  /// Формы словаря, не легшие ни в одну ячейку: сокращения под титлом и прочее.
  final List<LexemeForm> extra;

  const Lexeme({
    required this.id,
    required this.name,
    required this.scheme,
    required this.pos,
    required this.properties,
    required this.known,
    required this.paradigms,
    required this.extra,
  });

  factory Lexeme.fromJson(Map<String, dynamic> json) {
    final paradigms = json["paradigms"];
    final extra = json["extra"];
    return Lexeme(
      id: _asString(json["id"]),
      name: _asString(json["name"]),
      scheme: _asString(json["scheme"]),
      pos: _asString(json["pos"]),
      properties: _strings(json["properties"]),
      known: json["known"] == true,
      paradigms: paradigms is List
          ? paradigms
              .whereType<Map>()
              .map((row) => LexemeParadigm.fromJson(Map<String, dynamic>.from(row)))
              .toList()
          : const [],
      extra: extra is List
          ? extra
              .whereType<Map>()
              .map((row) => LexemeForm.fromJson(Map<String, dynamic>.from(row)))
              .toList()
          : const [],
    );
  }
}
