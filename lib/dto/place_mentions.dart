/// ЧТО КОРПУС ЗНАЕТ О МЕСТЕ: статьи, отождествления, Писание, чтения,
/// песнопения, святые.
///
/// Приходит отдельной ручкой от самой карточки: карточка — путь по ссылке из
/// текста, а это — шесть сводов и обращение к певческому корпусу.
///
/// **Стихов здесь нет, только их число по книгам.** У Иерусалима их 773, и с
/// отрывками они весят втрое больше всего прочего вместе взятого; сами стихи
/// спрашиваются по книге, когда читатель её раскроет.
library;

/// Текст корпуса: статья энциклопедии или чтение, где место названо.
class PlaceTextRef {
  final String id;
  final String? alias;
  final String name;
  final String? book;

  const PlaceTextRef({required this.id, required this.name, this.alias, this.book});

  /// Чем открывать чтение: устойчивый адрес, пока он есть.
  String get address => (alias?.isNotEmpty ?? false) ? alias! : id;

  factory PlaceTextRef.fromJson(Map<String, dynamic> json) => PlaceTextRef(
        id: "${json["id"] ?? ""}",
        alias: json["alias"],
        name: json["name"] ?? "",
        book: json["book"],
      );
}

/// Сосед по отождествлению, преемству или близости.
class PlaceRelation {
  /// `out` — от этого места, `in` — к нему. Подпись связи от этого меняется:
  /// «преемник» и «предшественник» — одна и та же запись с разных концов.
  final String direction;

  /// succeeds, identified_with, part_of, located_in, near.
  final String type;

  /// certain, probable, disputed.
  final String confidence;

  final String otherId;

  /// `null` — страница соседа скрыта: имя показываем, перехода нет.
  final String? otherSlug;
  final String otherName;
  final String? otherKind;
  final String? otherStatus;

  const PlaceRelation({
    required this.direction,
    required this.type,
    required this.confidence,
    required this.otherId,
    required this.otherName,
    this.otherSlug,
    this.otherKind,
    this.otherStatus,
  });

  bool get hasPage => otherSlug?.isNotEmpty ?? false;

  factory PlaceRelation.fromJson(Map<String, dynamic> json) {
    final other = json["other"] is Map
        ? Map<String, dynamic>.from(json["other"] as Map)
        : <String, dynamic>{};

    return PlaceRelation(
      direction: json["direction"] ?? "out",
      type: json["type"] ?? "near",
      confidence: json["confidence"] ?? "certain",
      otherId: "${other["id"] ?? ""}",
      otherSlug: other["slug"],
      otherName: other["name"] ?? "",
      otherKind: other["kind"],
      otherStatus: other["status"],
    );
  }
}

/// Книга Писания со счётом стихов: сами стихи догружаются по раскрытию.
class ScriptureBookRef {
  final String canonId;
  final String name;
  final String? abbr;
  final int verses;

  const ScriptureBookRef({
    required this.canonId,
    required this.name,
    required this.verses,
    this.abbr,
  });

  factory ScriptureBookRef.fromJson(Map<String, dynamic> json) => ScriptureBookRef(
        canonId: json["canonId"] ?? "",
        name: json["name"] ?? "",
        abbr: json["abbr"],
        verses: json["verses"] is num ? (json["verses"] as num).toInt() : 0,
      );
}

class ScriptureSummary {
  final int total;

  /// Стихи, которые ещё ждут сверки. Показывать их как факт нельзя, а промолчать
  /// о них — значит выдать неполный список за полный.
  final int pending;
  final List<ScriptureBookRef> books;

  const ScriptureSummary({this.total = 0, this.pending = 0, this.books = const []});

  factory ScriptureSummary.fromJson(Map<String, dynamic> json) => ScriptureSummary(
        total: json["total"] is num ? (json["total"] as num).toInt() : 0,
        pending: json["pending"] is num ? (json["pending"] as num).toInt() : 0,
        books: json["books"] is List
            ? (json["books"] as List)
                .whereType<Map>()
                .map((row) => ScriptureBookRef.fromJson(Map<String, dynamic>.from(row)))
                .toList()
            : const [],
      );
}

/// Стих Писания, где место названо.
class PlaceVerse {
  final String canonId;
  final String? abbr;
  final String canonRef;
  final int chapter;
  final int verse;
  final String context;

  const PlaceVerse({
    required this.canonId,
    required this.canonRef,
    required this.chapter,
    required this.verse,
    this.abbr,
    this.context = "",
  });

  factory PlaceVerse.fromJson(Map<String, dynamic> json) => PlaceVerse(
        canonId: json["canonId"] ?? "",
        abbr: json["abbr"],
        canonRef: json["canonRef"] ?? "",
        chapter: json["chapter"] is num ? (json["chapter"] as num).toInt() : 0,
        verse: json["verse"] is num ? (json["verse"] as num).toInt() : 0,
        context: json["context"] ?? "",
      );
}

/// Песнопение, где место названо.
class PlaceChantRef {
  final String id;
  final String? unit;
  final String? memory;
  final String context;

  const PlaceChantRef({required this.id, this.unit, this.memory, this.context = ""});

  factory PlaceChantRef.fromJson(Map<String, dynamic> json) => PlaceChantRef(
        id: "${json["id"] ?? ""}",
        unit: json["unit"],
        memory: json["memory"],
        context: json["context"] ?? "",
      );
}

class ChantMentions {
  final int total;
  final int shown;

  /// `false` — певческий корпус на сервере сейчас недоступен, и чем именно
  /// является каждая строка, неизвестно. Сами упоминания при этом настоящие,
  /// поэтому список показывается, а о подписях говорится словами: сорок строк
  /// «песнопение» подряд читались бы как поломка.
  final bool labelled;
  final List<PlaceChantRef> items;

  const ChantMentions({
    this.total = 0,
    this.shown = 0,
    this.labelled = true,
    this.items = const [],
  });

  factory ChantMentions.fromJson(Map<String, dynamic> json) => ChantMentions(
        total: json["total"] is num ? (json["total"] as num).toInt() : 0,
        shown: json["shown"] is num ? (json["shown"] as num).toInt() : 0,
        labelled: json["labelled"] != false,
        items: json["items"] is List
            ? (json["items"] as List)
                .whereType<Map>()
                .map((row) => PlaceChantRef.fromJson(Map<String, dynamic>.from(row)))
                .toList()
            : const [],
      );
}

/// Святой, в чтениях к памяти которого место названо.
class PlaceSaintRef {
  final String dneslovId;
  final String? slug;
  final String name;
  final int texts;

  const PlaceSaintRef({
    required this.dneslovId,
    required this.name,
    this.slug,
    this.texts = 0,
  });

  factory PlaceSaintRef.fromJson(Map<String, dynamic> json) => PlaceSaintRef(
        dneslovId: "${json["dneslovId"] ?? ""}",
        slug: json["slug"],
        name: json["name"] ?? "",
        texts: json["texts"] is num ? (json["texts"] as num).toInt() : 0,
      );
}

class PlaceMentions {
  final List<PlaceTextRef> articles;
  final List<PlaceRelation> relations;
  final ScriptureSummary scripture;
  final List<PlaceTextRef> texts;

  /// Чтений больше, чем отдано: предел выборки — двести.
  final bool textsTruncated;
  final ChantMentions chants;
  final List<PlaceSaintRef> saints;

  /// Оговорка к разделу святых и ссылка на источники — обе с сервера.
  ///
  /// Первая потому, что связь выведена, а не размечена; вторая — потому что это
  /// условие лицензий, и формулировка обязана быть одна на все поверхности.
  final String saintsCaveat;
  final String attribution;

  const PlaceMentions({
    this.articles = const [],
    this.relations = const [],
    this.scripture = const ScriptureSummary(),
    this.texts = const [],
    this.textsTruncated = false,
    this.chants = const ChantMentions(),
    this.saints = const [],
    this.saintsCaveat = "",
    this.attribution = "",
  });

  bool get isEmpty =>
      articles.isEmpty &&
      relations.isEmpty &&
      scripture.books.isEmpty &&
      texts.isEmpty &&
      chants.items.isEmpty &&
      saints.isEmpty;

  factory PlaceMentions.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) of) =>
        json[key] is List
            ? (json[key] as List)
                .whereType<Map>()
                .map((row) => of(Map<String, dynamic>.from(row)))
                .toList()
            : const [];

    Map<String, dynamic> nested(String key) => json[key] is Map
        ? Map<String, dynamic>.from(json[key] as Map)
        : <String, dynamic>{};

    return PlaceMentions(
      articles: list("articles", PlaceTextRef.fromJson),
      relations: list("relations", PlaceRelation.fromJson),
      scripture: ScriptureSummary.fromJson(nested("scripture")),
      texts: list("texts", PlaceTextRef.fromJson),
      textsTruncated: json["textsTruncated"] == true,
      chants: ChantMentions.fromJson(nested("chants")),
      saints: list("saints", PlaceSaintRef.fromJson),
      saintsCaveat: json["saintsCaveat"] ?? "",
      attribution: json["attribution"] ?? "",
    );
  }
}
