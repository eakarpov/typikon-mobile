/// МЕСТО: то, что помечено в тексте географическим именем.
///
/// Разбор терпим к пропускам нарочно. Записи заводились и руками, и тремя
/// импортами подряд: у пустыни Иорданской нет точки, у половины мест нет рода,
/// у иных координаты до сих пор лежат строками. Строгий разбор ронял бы карточку
/// целиком там, где не хватает одного поля.
library;

class TextLink {
  final String? text;
  final String? url;

  const TextLink({
    required this.url,
    required this.text,
  });

  factory TextLink.fromJson(Map<String, dynamic> json) {
    return TextLink(
      text: json["text"],
      url: json["url"],
    );
  }
}

/// Координата: числом, строкой или её отсутствием.
///
/// В базе они лежат строками, вторая версия API приводит их к числу, а места без
/// точки бывают и вовсе. Прежде здесь стоял `double.parse`, и первое же такое
/// место роняло карточку.
double? placeCoordinate(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Имя места в свою эпоху.
class PlaceName {
  final String name;

  /// Латинская запись — для имён, набранных не кириллицей.
  final String? transliteration;

  /// Язык: ru, csl, grc, heb, lat…
  final String lang;

  /// Какого рода имя: biblical, slavonic, historical, modern, variant.
  final String role;

  /// Годы бытования. До Рождества Христова — отрицательные.
  final int? from;
  final int? to;

  final String? source;

  const PlaceName({
    required this.name,
    required this.lang,
    required this.role,
    this.transliteration,
    this.from,
    this.to,
    this.source,
  });

  factory PlaceName.fromJson(Map<String, dynamic> json) => PlaceName(
        name: json["name"] ?? "",
        transliteration: json["transliteration"],
        lang: json["lang"] ?? "",
        role: json["role"] ?? "variant",
        from: json["from"] is num ? (json["from"] as num).toInt() : null,
        to: json["to"] is num ? (json["to"] as num).toInt() : null,
        source: json["source"],
      );
}

/// Эпоха в жизни места: «Византий», «Второй Рим».
class PlacePeriod {
  final String label;
  final int? from;
  final int? to;
  final String? source;

  const PlacePeriod({required this.label, this.from, this.to, this.source});

  factory PlacePeriod.fromJson(Map<String, dynamic> json) => PlacePeriod(
        label: json["label"] ?? "",
        from: json["from"] is num ? (json["from"] as num).toInt() : null,
        to: json["to"] is num ? (json["to"] as num).toInt() : null,
        source: json["source"],
      );
}

/// Ключ места в чужой базе: wikidata, pleiades, openbible, nikifor.
class PlaceExternal {
  final String source;
  final String id;

  const PlaceExternal({required this.source, required this.id});

  factory PlaceExternal.fromJson(Map<String, dynamic> json) => PlaceExternal(
        source: json["source"] ?? "",
        id: "${json["id"] ?? ""}",
      );
}

/// Место в указателе.
class PlaceSummary {
  final String id;
  final String? slug;
  final String name;
  final String? kind;
  final String? status;
  final double? latitude;
  final double? longitude;

  /// Принятых упоминаний в Писании.
  final int scripture;

  const PlaceSummary({
    required this.id,
    required this.name,
    this.slug,
    this.kind,
    this.status,
    this.latitude,
    this.longitude,
    this.scripture = 0,
  });

  /// Чем спрашивать место у сервера и чем открывать его страницу.
  ///
  /// Наш адрес, пока он есть; иначе опознаватель. Разметка в текстах ссылается
  /// то на одно, то на другое, и обе формы ручка принимает.
  String get address => (slug?.isNotEmpty ?? false) ? slug! : id;

  bool get hasPoint => latitude != null && longitude != null;

  factory PlaceSummary.fromJson(Map<String, dynamic> json) => PlaceSummary(
        id: "${json["id"] ?? json["_id"] ?? ""}",
        slug: json["slug"],
        name: json["name"] ?? "",
        kind: json["kind"],
        status: json["status"],
        latitude: placeCoordinate(json["latitude"]),
        longitude: placeCoordinate(json["longitude"]),
        scripture: json["scripture"] is num ? (json["scripture"] as num).toInt() : 0,
      );
}

/// Роды мест, встретившиеся в нынешней выдаче, со счётом.
///
/// Приходят с сервера, а не зашиты здесь: заведут в корпусе новый род — он
/// появится сам. Зашитый перечень разошёлся бы молча.
class PlaceKindCount {
  final String code;
  final int total;

  const PlaceKindCount({required this.code, required this.total});

  factory PlaceKindCount.fromJson(Map<String, dynamic> json) => PlaceKindCount(
        code: json["code"] ?? "",
        total: json["total"] is num ? (json["total"] as num).toInt() : 0,
      );
}

class PlaceFacets {
  final List<PlaceKindCount> kinds;

  const PlaceFacets({this.kinds = const []});

  factory PlaceFacets.fromJson(Map<String, dynamic> json) => PlaceFacets(
        kinds: json["kinds"] is List
            ? (json["kinds"] as List)
                .whereType<Map>()
                .map((row) => PlaceKindCount.fromJson(Map<String, dynamic>.from(row)))
                .toList()
            : const [],
      );
}

/// Место целиком.
class PlaceDetail {
  final String id;
  final String? slug;
  final String? alias;
  final String name;
  final String? description;
  final String? kind;
  final String? status;
  final double? latitude;
  final double? longitude;
  final List<String> synonyms;
  final List<TextLink> links;
  final List<PlaceName> names;
  final List<PlacePeriod> periods;
  final List<PlaceExternal> externals;

  const PlaceDetail({
    required this.id,
    required this.name,
    this.slug,
    this.alias,
    this.description,
    this.kind,
    this.status,
    this.latitude,
    this.longitude,
    this.synonyms = const [],
    this.links = const [],
    this.names = const [],
    this.periods = const [],
    this.externals = const [],
  });

  String get address => (slug?.isNotEmpty ?? false) ? slug! : id;

  bool get hasPoint => latitude != null && longitude != null;

  factory PlaceDetail.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) of) =>
        json[key] is List
            ? (json[key] as List)
                .whereType<Map>()
                .map((row) => of(Map<String, dynamic>.from(row)))
                .toList()
            : const [];

    return PlaceDetail(
      id: "${json["id"] ?? json["_id"] ?? ""}",
      slug: json["slug"],
      alias: json["alias"],
      name: json["name"] ?? "",
      description: json["description"],
      kind: json["kind"],
      status: json["status"],
      latitude: placeCoordinate(json["latitude"]),
      longitude: placeCoordinate(json["longitude"]),
      synonyms: json["synonyms"] is List
          ? List<String>.from((json["synonyms"] as List).whereType<String>())
          : const [],
      links: list("links", TextLink.fromJson),
      names: list("names", PlaceName.fromJson),
      periods: list("periods", PlacePeriod.fromJson),
      externals: list("externals", PlaceExternal.fromJson),
    );
  }
}

/// Место, названное в тексте чтения.
class TextPlaceRef {
  final String id;
  final String? slug;
  final String name;

  /// Текст — статья об этом месте, а не упоминание его в чтении.
  final bool subject;

  const TextPlaceRef({
    required this.id,
    required this.name,
    this.slug,
    this.subject = false,
  });

  String get address => (slug?.isNotEmpty ?? false) ? slug! : id;

  factory TextPlaceRef.fromJson(Map<String, dynamic> json) => TextPlaceRef(
        id: "${json["id"] ?? ""}",
        slug: json["slug"],
        name: json["name"] ?? "",
        subject: json["subject"] == true,
      );
}

/// Место, названное в главе Библии.
class ChapterPlace {
  final String id;

  /// `null` — страница места скрыта: имя показываем, перехода нет.
  final String? slug;
  final String name;

  /// Стихи главы в канонической нумерации.
  final List<int> verses;

  const ChapterPlace({
    required this.id,
    required this.name,
    this.slug,
    this.verses = const [],
  });

  bool get hasPage => slug?.isNotEmpty ?? false;

  factory ChapterPlace.fromJson(Map<String, dynamic> json) => ChapterPlace(
        id: "${json["id"] ?? ""}",
        slug: json["slug"],
        name: json["name"] ?? "",
        verses: json["verses"] is List
            ? (json["verses"] as List)
                .whereType<num>()
                .map((v) => v.toInt())
                .toList()
            : const [],
      );
}
