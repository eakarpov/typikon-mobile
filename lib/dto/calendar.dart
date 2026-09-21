import 'package:typikon/dto/pericope.dart';

export 'package:typikon/dto/pericope.dart';

/// Один айтем литургического слота дня — либо прямая ссылка на текст
/// (`text`), либо резолвленное зачало (`pericope`), присланное бекендом
/// вместо стихов для нужного языка Библии.
class CalendarDayPartItem {
  final String name;
  final String? id;
  final String content; // текст прямого чтения; для зачал пусто, используйте verses
  final String cite;
  final String description;
  final String? pericopeSource; // "gospel" | "apostle" | "paremia" | null

  /// Книга канона, из которой взято зачало, — адрес для раздела Библии.
  final String? bookSlug;
  final List<PericopeVerse>? verses; // не null только для зачал с найденными стихами

  /// Границы зачала в книге. Пусто для прямых чтений; для зачал по ним
  /// страница полного текста подсвечивает, где чтение начинается и кончается.
  final List<PericopeRange> ranges;
  final bool isPericope;

  const CalendarDayPartItem({
    required this.name,
    required this.id,
    required this.content,
    required this.cite,
    required this.description,
    required this.pericopeSource,
    required this.bookSlug,
    required this.verses,
    this.ranges = const [],
    required this.isPericope,
  });

  factory CalendarDayPartItem.fromJson(Map<String, dynamic> json) {
    var text = json["text"];
    var cite = json["cite"] ?? "";
    var description = json["description"] ?? "";
    final pericope = Pericope.fromJson(json["pericope"]);
    if (pericope != null) {
      return CalendarDayPartItem(
        name: pericope.label,
        // Идентификатор зачала сюда НЕ кладём. Прежде здесь стоял
        // pericope.textId, а он с переездом Библии указывает на bible_books:
        // всякий, кто им воспользуется, уедет в пустой ответ. Заодно это чистит
        // textIds, по которым предзагрузчик заранее качал тексты дня — он качал
        // пустоту и складывал её в кэш.
        id: null,
        content: "",
        cite: cite,
        description: description,
        pericopeSource: pericope.source,
        bookSlug: pericope.bookSlug,
        verses: pericope.verses.isEmpty ? null : pericope.verses,
        ranges: pericope.ranges,
        isPericope: true,
      );
    }
    return CalendarDayPartItem(
      name: text == null ? "" : (text["name"] ?? ""),
      // `id`, а не только `_id`. Вторая версия API переименовала опознаватель,
      // и здесь это пропустили: у обычного чтения id выходил пустым, а значит
      // на главной по нему нельзя было перейти — плитка просто не нажималась.
      // Зачала при этом переходили, потому что ведут не по id, а по книге и
      // границам. Старое имя читаем следом: в кэше сутки лежат прежние ответы.
      id: text == null ? null : (text["id"] ?? text["_id"]),
      content: text == null ? "" : (text["content"] ?? ""),
      cite: cite,
      description: description,
      pericopeSource: null,
      bookSlug: null,
      verses: null,
      ranges: const [],
      isPericope: false,
    );
  }
}

class CalendarDayPart {
  final List<CalendarDayPartItem>? items;

  const CalendarDayPart({
    required this.items,
  });

  factory CalendarDayPart.fromJson(Map<String, dynamic> json) {
    var list = json["items"] == null ? [] : json["items"];
    List<CalendarDayPartItem> items = List<CalendarDayPartItem>.from(
        list
            .map((item) => CalendarDayPartItem.fromJson(item))
            .toList()
    );
    return CalendarDayPart(
      items: items,
    );
  }
}

class DayMemory {
  final String id;
  final String name;
  final String sign;
  final bool signConditional;
  final int order;

  const DayMemory({
    required this.id,
    required this.name,
    required this.sign,
    required this.signConditional,
    required this.order,
  });

  factory DayMemory.fromJson(Map<String, dynamic> json) {
    return DayMemory(
      id: json["id"] ?? "",
      name: json["name"] ?? "",
      sign: json["sign"] ?? "NO_SIGN",
      signConditional: json["signConditional"] ?? false,
      order: json["order"] is int ? json["order"] : int.tryParse("${json["order"]}") ?? 0,
    );
  }
}

class DayMemories {
  final DayMemory? defaultMemory;
  final List<DayMemory> secondary;

  const DayMemories({
    required this.defaultMemory,
    required this.secondary,
  });

  factory DayMemories.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const DayMemories(defaultMemory: null, secondary: []);
    }
    var secondaryList = json["secondary"];
    return DayMemories(
      // Вторая версия API зовёт её `primary`, движок устава звал `default`.
      // Слово одно и то же — память, которой день назван; читаем оба.
      defaultMemory: (json["primary"] ?? json["default"]) == null
          ? null
          : DayMemory.fromJson(json["primary"] ?? json["default"]),
      secondary: secondaryList is List
          ? secondaryList.map((m) => DayMemory.fromJson(m)).toList()
          : [],
    );
  }

  bool get isEmpty => defaultMemory == null && secondary.isEmpty;
}

class CalendarDay {
  final String name;

  /// Постоянный адрес дня: по нему открывается экран службы.
  final String? alias;

  // На вечерне/утрене
  final CalendarDayPart? vespersProkimenon;
  final CalendarDayPart? vigil;
  final CalendarDayPart? kathisma1;
  final CalendarDayPart? kathisma2;
  final CalendarDayPart? kathisma3;
  final CalendarDayPart? ipakoi;
  final CalendarDayPart? polyeleos;
  final CalendarDayPart? song3;
  final CalendarDayPart? song6;
  final CalendarDayPart? gospelMatins;
  final CalendarDayPart? apolutikaTroparia;
  final CalendarDayPart? before50;

  // На часах и Литургии
  final CalendarDayPart? before1h;
  final CalendarDayPart? h1;
  final CalendarDayPart? h3;
  final CalendarDayPart? h6;
  final CalendarDayPart? h9;
  final CalendarDayPart? panagia;
  final CalendarDayPart? apostleLiturgy;
  final CalendarDayPart? gospelLiturgy;

  /// Места службы списком, как их отдаёт вторая версия API: с готовым
  /// заголовком и в порядке хода службы.
  ///
  /// Двадцать полей выше остаются ради ответов первой версии, лежащих в кэше
  /// сутками (а прошедшие даты — годами). Новый показ идёт по этому списку:
  /// третьей копии перечня мест службы в приложении быть не должно — две уже
  /// однажды разошлись, и Великий пяток потерял два чтения.
  final List<CalendarSection> readings;

  final DayMemories memories;

  const CalendarDay({
    required this.name,
    this.alias,
    this.readings = const [],
    required this.vespersProkimenon,
    required this.vigil,
    required this.kathisma1,
    required this.kathisma2,
    required this.kathisma3,
    required this.ipakoi,
    required this.polyeleos,
    required this.song3,
    required this.song6,
    required this.gospelMatins,
    required this.apolutikaTroparia,
    required this.before50,
    required this.before1h,
    required this.h1,
    required this.h3,
    required this.h6,
    required this.h9,
    required this.panagia,
    required this.apostleLiturgy,
    required this.gospelLiturgy,
    required this.memories,
  });

  /// Все места службы одним списком — для обхода, а не для показа. Порядок тот
  /// же, в каком места идут на странице дня.
  List<CalendarDayPart?> get parts => [
    vespersProkimenon,
    vigil,
    kathisma1,
    kathisma2,
    kathisma3,
    before50,
    ipakoi,
    polyeleos,
    gospelMatins,
    song3,
    song6,
    apolutikaTroparia,
    before1h,
    h1,
    h3,
    h6,
    h9,
    apostleLiturgy,
    gospelLiturgy,
    panagia,
  ];

  /// Идентификаторы текстов дня, без повторов и в порядке службы. Один и тот же
  /// текст нередко стоит сразу в нескольких местах.
  List<String> get textIds {
    final seen = <String>{};
    for (final part in parts) {
      for (final item in part?.items ?? const <CalendarDayPartItem>[]) {
        final id = item.id;
        if (id != null && id.isNotEmpty) seen.add(id);
      }
    }
    return seen.toList();
  }

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    final day = json["day"];
    CalendarDayPart? part(String key) =>
        day == null || day[key] == null ? null : CalendarDayPart.fromJson(day[key]);
    return CalendarDay(
      name: day == null ? "" : (day['name'] ?? ""),
      alias: day is Map ? day["alias"] : null,
      vespersProkimenon: part("vespersProkimenon"),
      vigil: part("vigil"),
      kathisma1: part("kathisma1"),
      kathisma2: part("kathisma2"),
      kathisma3: part("kathisma3"),
      ipakoi: part("ipakoi"),
      polyeleos: part("polyeleos"),
      song3: part("song3"),
      song6: part("song6"),
      gospelMatins: part("gospelMatins"),
      apolutikaTroparia: part("apolutikaTroparia"),
      before50: part("before50"),
      before1h: part("before1h"),
      h1: part("h1"),
      h3: part("h3"),
      h6: part("h6"),
      h9: part("h9"),
      panagia: part("panagia"),
      apostleLiturgy: part("apostleLiturgy"),
      gospelLiturgy: part("gospelLiturgy"),
      readings: day is Map && day["readings"] is List
          ? (day["readings"] as List)
              .whereType<Map>()
              .map((r) => CalendarSection.fromJson(Map<String, dynamic>.from(r)))
              .toList()
          : _sectionsFromSlots(day),
      memories: DayMemories.fromJson(json["memories"]),
    );
  }

  /// Ответ первой версии: места службы полями по имени.
  ///
  /// Порядок и подписи приходится знать самим — другого источника у такого
  /// ответа нет. Список нужен только для того, что уже лежит в кэше; новые
  /// ответы несут `readings` с сервера.
  static List<CalendarSection> _sectionsFromSlots(dynamic day) {
    if (day is! Map) return const [];

    const slots = <String, String>{
      "vespersProkimenon": "На паремиях вечерни по прокимне",
      "vigil": "На всенощном бдении перед шестопсалмием",
      "kathisma1": "По седальнах первой кафизмы",
      "kathisma2": "По седальнах второй кафизмы",
      "kathisma3": "По седальнах третьей кафизмы",
      "before50": "Перед 50 псалмом",
      "ipakoi": "По ипакои",
      "polyeleos": "По седальнах полиелея",
      "gospelMatins": "Евангелие на утрени",
      "song3": "По седальнах третьей песни",
      "song6": "По шестой песни",
      "apolutikaTroparia": "По отпустительным тропарям",
      "before1h": "Перед первым часом",
      "h1": "На первом часе",
      "h3": "На третьем часе",
      "h6": "На шестом часе",
      "h9": "На девятом часе",
      "panagia": "На панагии",
      "apostleLiturgy": "Апостол на Литургии",
      "gospelLiturgy": "Евангелие на Литургии",
    };

    final out = <CalendarSection>[];
    slots.forEach((slot, title) {
      final raw = day[slot];
      if (raw is! Map) return;
      final part = CalendarDayPart.fromJson(Map<String, dynamic>.from(raw));
      if (part.items?.isEmpty ?? true) return;
      out.add(CalendarSection(slot: slot, title: title, items: part.items!));
    });
    return out;
  }
}

/// Место службы в ответе календаря.
class CalendarSection {
  final String slot;
  final String title;
  final List<CalendarDayPartItem> items;

  const CalendarSection({
    required this.slot,
    required this.title,
    this.items = const [],
  });

  factory CalendarSection.fromJson(Map<String, dynamic> json) => CalendarSection(
        slot: json["slot"] ?? "",
        title: json["title"] ?? "",
        items: json["items"] is List
            ? (json["items"] as List)
                .whereType<Map>()
                .map((i) => CalendarDayPartItem.fromJson(Map<String, dynamic>.from(i)))
                .toList()
            : const <CalendarDayPartItem>[],
      );
}
