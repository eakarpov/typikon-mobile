// Каноны, акафисты и молитвы певческого корпуса.
//
// Одним файлом, а не тремя: у всех трёх один конверт выдачи — постраничный, с
// отборами, — и разложив их порознь, конверт пришлось бы или трижды повторить,
// или завести четвёртым файлом ради одного класса.
//
// Отборы приезжают ВМЕСТЕ С ВЫДАЧЕЙ, и в этом всё дело. Значения берутся из
// самого корпуса; список, приехавший с ответом, разойтись с ним не может, а
// зашитый у нас разошёлся бы молча — как только в корпусе заведут новую роль
// или книгу. Ровно поэтому у поиска по песнопениям фильтров нет до сих пор.

/// Страница выдачи вместе с тем, чем её можно сузить.
class FacetedPage<T, F> {
  final List<T> items;
  final int total;
  final int limit;
  final int offset;
  final F facets;

  const FacetedPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.facets,
  });

  /// Считаем по числу полученного, а не по `offset + limit`: сервер вправе
  /// отдать меньше запрошенного. То же правило, что у `Paged`.
  bool get hasMore => items.isNotEmpty && offset + items.length < total;

  static FacetedPage<T, F> fromJson<T, F>(
    dynamic json,
    T Function(Map<String, dynamic>) item,
    F Function(Map<String, dynamic>) facets,
  ) {
    if (json is! Map) {
      throw const FormatException("Ожидалась страница выдачи");
    }
    final rows = json["items"];
    return FacetedPage<T, F>(
      items: rows is List
          ? rows.whereType<Map>().map((row) => item(Map<String, dynamic>.from(row))).toList()
          : <T>[],
      total: json["total"] is int ? json["total"] : 0,
      limit: json["limit"] is int ? json["limit"] : 0,
      offset: json["offset"] is int ? json["offset"] : 0,
      facets: facets(json["facets"] is Map
          ? Map<String, dynamic>.from(json["facets"])
          : const <String, dynamic>{}),
    );
  }
}

List<String> _strings(dynamic raw) =>
    raw is List ? raw.whereType<String>().toList() : const <String>[];

List<int> _ints(dynamic raw) => raw is List ? raw.whereType<int>().toList() : const <int>[];

// --- Канон ---------------------------------------------------------------------

class CanonFacets {
  final List<String> books;
  final List<int> tones;
  final List<String> services;
  final List<String> roles;

  const CanonFacets({
    this.books = const [],
    this.tones = const [],
    this.services = const [],
    this.roles = const [],
  });

  factory CanonFacets.fromJson(Map<String, dynamic> json) => CanonFacets(
        books: _strings(json["books"]),
        tones: _ints(json["tones"]),
        services: _strings(json["services"]),
        roles: _strings(json["roles"]),
      );
}

class Canon {
  final String id;

  /// Кому канон: метка памяти, под которой он напечатан.
  final String memory;

  final String? book;
  final int? month;
  final int? day;
  final int? paschaOffset;
  final String? weekday;

  /// Глас памяти у Октоиха — **не то же**, что глас самого канона.
  final int? memoryTone;

  final int? tone;

  /// Надписание, как напечатано книгой: «Творе́ние Ио́сифово. Гла́с 2.»
  ///
  /// Напечатанное есть свидетельство; [author] — вывод из него, и вывод бывает
  /// неверен. Оттого они стоят порознь, а где отождествления нет, остаётся одно
  /// надписание: гадать за книгу мы не станем.
  final String? creator;

  final String? author;
  final String? authorCentury;
  final String? acrostic;
  final String? service;
  final String? role;

  /// Язык издания. Без него английский канон в перечне неотличим от
  /// славянского: подписи у них одни и те же, а текст — на разных языках.
  final String? language;

  final int odes;

  const Canon({
    required this.id,
    required this.memory,
    this.book,
    this.month,
    this.day,
    this.paschaOffset,
    this.weekday,
    this.memoryTone,
    this.tone,
    this.creator,
    this.author,
    this.authorCentury,
    this.acrostic,
    this.service,
    this.role,
    this.language,
    this.odes = 0,
  });

  /// Лицо словами, если оно названо: «Иосиф Песнописец, IX в.»
  String get authorLabel {
    if ((author ?? "").isEmpty) return "";
    return (authorCentury ?? "").isEmpty ? author! : "$author, $authorCentury в.";
  }

  factory Canon.fromJson(Map<String, dynamic> json) => Canon(
        id: json["id"] ?? "",
        memory: json["memory"] ?? "",
        book: json["book"],
        month: json["month"],
        day: json["day"],
        paschaOffset: json["paschaOffset"],
        weekday: json["weekday"],
        memoryTone: json["memoryTone"],
        tone: json["tone"],
        creator: json["creator"],
        author: json["author"],
        authorCentury: json["authorCentury"],
        acrostic: json["acrostic"],
        service: json["service"],
        role: json["role"],
        language: json["language"],
        odes: json["odes"] is int ? json["odes"] : 0,
      );
}

class CanonLine {
  final String? unit;
  final String text;

  /// Текста своего нет — он взят по ссылке. Книга печатает ирмос зачином
  /// («Ирмо́с: Христо́с ражда́ется:»), а полный лежит в Ирмологии; показать его
  /// неподписанным значило бы выдать отсылку за песнопение.
  final bool borrowed;

  /// Ссылка, которую разрешить не удалось: греческий слой ссылается на
  /// Ирмологий, которого в корпусе нет. Текста при ней не бывает, и печатать
  /// опознаватель `he.h.m2.heHE.DefteLaoi` уставным кеглем нельзя — читатель
  /// прочтёт машинную строку как ирмос.
  final String? reference;

  final String? marker;

  /// «Ирмо́с по два́жды» — указание книги, а не украшение.
  final int repeat;

  const CanonLine({
    required this.text,
    this.unit,
    this.borrowed = false,
    this.reference,
    this.marker,
    this.repeat = 1,
  });

  /// Есть ссылка, а песнопения по ней нет.
  bool get isUnresolved => (reference ?? "").isNotEmpty;

  factory CanonLine.fromJson(Map<String, dynamic> json) => CanonLine(
        text: json["text"] ?? "",
        unit: json["unit"],
        borrowed: json["borrowed"] == true,
        reference: json["reference"],
        marker: json["marker"],
        repeat: json["repeat"] is int ? json["repeat"] : 1,
      );
}

class CanonOde {
  /// Номер песни, **как в книге**.
  ///
  /// Нумерация не сплошная: второй песни нет ни у кого, кроме Великого канона,
  /// а трипеснцы Триоди несут три и меньше. «Песнь 3» после «Песни 1» — это как
  /// напечатано, а не пропуск разбора; перенумеровав их подряд, мы «починили»
  /// бы пропуск, которого нет.
  final int ode;

  final List<CanonLine> irmos;
  final List<CanonLine> troparia;

  const CanonOde({required this.ode, this.irmos = const [], this.troparia = const []});

  factory CanonOde.fromJson(Map<String, dynamic> json) => CanonOde(
        ode: json["ode"] is int ? json["ode"] : 0,
        irmos: _lines(json["irmos"]),
        troparia: _lines(json["troparia"]),
      );

  static List<CanonLine> _lines(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((e) => CanonLine.fromJson(Map<String, dynamic>.from(e))).toList()
      : const <CanonLine>[];
}

class CanonDetail {
  final Canon canon;
  final List<CanonOde> odes;

  const CanonDetail({required this.canon, this.odes = const []});

  factory CanonDetail.fromJson(Map<String, dynamic> json) => CanonDetail(
        canon: Canon.fromJson(json),
        odes: json["odesList"] is List
            ? (json["odesList"] as List)
                .whereType<Map>()
                .map((e) => CanonOde.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <CanonOde>[],
      );
}

// --- Акафист -------------------------------------------------------------------

class AkathistFacets {
  final List<String> subjectKinds;
  final List<String> statuses;

  const AkathistFacets({this.subjectKinds = const [], this.statuses = const []});

  factory AkathistFacets.fromJson(Map<String, dynamic> json) => AkathistFacets(
        subjectKinds: _strings(json["subjectKinds"]),
        statuses: _strings(json["statuses"]),
      );
}

class Akathist {
  final String id;
  final String title;

  /// Кому. «Пред иконой» отдельно от «Богородице»: акафист пред иконой обращён
  /// к иконе, и свести их в одно значило бы соврать в одном из двух.
  final String? subjectKind;

  /// Чем акафист является уставу.
  ///
  /// **Показывать обязательно.** Уставом положен ровно один — Великий;
  /// остальные тысяча сто один в сборку служб не идут, и перечень без этой
  /// пометы обещал бы читателю обратное.
  final String? status;

  final String? dneslovId;

  /// Служба, в которой напечатан. Есть только у Великого.
  final String? memory;

  final int stanzas;

  /// Проимиев бывает несколько, и счёт у них свой.
  final int prooimia;

  const Akathist({
    required this.id,
    required this.title,
    this.subjectKind,
    this.status,
    this.dneslovId,
    this.memory,
    this.stanzas = 0,
    this.prooimia = 0,
  });

  bool get isUstavny => status == "ustavny";

  factory Akathist.fromJson(Map<String, dynamic> json) => Akathist(
        id: json["id"] ?? "",
        title: json["title"] ?? "",
        subjectKind: json["subjectKind"],
        status: json["status"],
        dneslovId: json["dneslovId"],
        memory: json["memory"],
        stanzas: json["stanzas"] is int ? json["stanzas"] : 0,
        prooimia: json["prooimia"] is int ? json["prooimia"] : 0,
      );
}

class AkathistStanza {
  /// Порядок чтения; он же порядок показа.
  final int index;

  /// Проимий или строфа акростиха. Различает именно это, а не номер:
  /// акростишный «кондак 2» и второй проимий несут одно число.
  final String? kind;

  final String? unit;
  final int? stanza;

  /// Буква краегранесия. У Великого акафиста двадцать четыре строфы идут по
  /// греческому алфавиту, и недостающая буква значит потерянную строфу.
  final String? letter;

  final String text;

  const AkathistStanza({
    required this.index,
    required this.text,
    this.kind,
    this.unit,
    this.stanza,
    this.letter,
  });

  bool get isProoimion => kind == "prooimion";

  factory AkathistStanza.fromJson(Map<String, dynamic> json) => AkathistStanza(
        index: json["index"] is int ? json["index"] : 0,
        text: json["text"] ?? "",
        kind: json["kind"],
        unit: json["unit"],
        stanza: json["stanza"],
        letter: json["letter"],
      );
}

class AkathistDetail {
  final Akathist akathist;

  /// Рефрен: им кончается каждый икос, и по нему акафист опознают.
  final String? refrainIkos;

  final String? refrainKontakion;
  final String? sourceBook;
  final String? sourceUrl;
  final List<AkathistStanza> stanzas;

  /// Молитва при акафисте — не строфа: у неё нет ни номера, ни места в
  /// акростихе. Но печатается она здесь же, и читателю нужна здесь же.
  final List<Prayer> prayers;

  const AkathistDetail({
    required this.akathist,
    this.refrainIkos,
    this.refrainKontakion,
    this.sourceBook,
    this.sourceUrl,
    this.stanzas = const [],
    this.prayers = const [],
  });

  factory AkathistDetail.fromJson(Map<String, dynamic> json) => AkathistDetail(
        akathist: Akathist.fromJson(json),
        refrainIkos: json["refrainIkos"],
        refrainKontakion: json["refrainKontakion"],
        sourceBook: json["sourceBook"],
        sourceUrl: json["sourceUrl"],
        stanzas: json["stanzasList"] is List
            ? (json["stanzasList"] as List)
                .whereType<Map>()
                .map((e) => AkathistStanza.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <AkathistStanza>[],
        prayers: json["prayers"] is List
            ? (json["prayers"] as List)
                .whereType<Map>()
                .map((e) => Prayer.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <Prayer>[],
      );
}

// --- Молитва -------------------------------------------------------------------

class PrayerFacets {
  final List<String> kinds;

  const PrayerFacets({this.kinds = const []});

  factory PrayerFacets.fromJson(Map<String, dynamic> json) =>
      PrayerFacets(kinds: _strings(json["kinds"]));
}

class Prayer {
  final String id;

  /// Двести тридцать пять из тысячи подписаны просто «Моли́тва»: имени у молитвы
  /// почти нет, и называет её тот, при ком она стоит.
  final String? title;

  final String? kind;
  final String? owner;
  final String? ownerId;
  final int seq;

  /// Начало текста — то единственное, чем две молитвы одного акафиста
  /// различаются.
  final String? incipit;

  const Prayer({
    required this.id,
    this.title,
    this.kind,
    this.owner,
    this.ownerId,
    this.seq = 1,
    this.incipit,
  });

  String get display => (title ?? "").isEmpty ? "Молитва" : title!;

  factory Prayer.fromJson(Map<String, dynamic> json) => Prayer(
        id: json["id"] ?? "",
        title: json["title"],
        kind: json["kind"],
        owner: json["owner"],
        ownerId: json["ownerId"],
        seq: json["seq"] is int ? json["seq"] : 1,
        incipit: json["incipit"],
      );
}

class PrayerSibling {
  final String id;
  final String? title;
  final int seq;

  const PrayerSibling({required this.id, this.title, this.seq = 1});

  String get display => (title ?? "").isEmpty ? "Молитва" : title!;

  factory PrayerSibling.fromJson(Map<String, dynamic> json) => PrayerSibling(
        id: json["id"] ?? "",
        title: json["title"],
        seq: json["seq"] is int ? json["seq"] : 1,
      );
}

class PrayerDetail {
  final Prayer prayer;
  final String text;
  final String? language;
  final String? sourceBook;
  final String? sourceUrl;

  /// Что напечатано здесь же: книга печатает молитвы вереницей, и читающий
  /// вторую обыкновенно хочет и первую.
  final List<PrayerSibling> siblings;

  const PrayerDetail({
    required this.prayer,
    required this.text,
    this.language,
    this.sourceBook,
    this.sourceUrl,
    this.siblings = const [],
  });

  factory PrayerDetail.fromJson(Map<String, dynamic> json) => PrayerDetail(
        prayer: Prayer.fromJson(json),
        text: json["text"] ?? "",
        language: json["language"],
        sourceBook: json["sourceBook"],
        sourceUrl: json["sourceUrl"],
        siblings: json["siblings"] is List
            ? (json["siblings"] as List)
                .whereType<Map>()
                .map((e) => PrayerSibling.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <PrayerSibling>[],
      );
}
