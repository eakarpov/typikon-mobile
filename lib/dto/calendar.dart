class PericopeVerse {
  final int chapter;
  final int verse;
  final String content;

  const PericopeVerse({
    required this.chapter,
    required this.verse,
    required this.content,
  });

  factory PericopeVerse.fromJson(Map<String, dynamic> json) {
    return PericopeVerse(
      chapter: json["chapter"] is int ? json["chapter"] : int.tryParse("${json["chapter"]}") ?? 0,
      verse: json["verse"] is int ? json["verse"] : int.tryParse("${json["verse"]}") ?? 0,
      content: json["content"] ?? "",
    );
  }
}

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
  final List<PericopeVerse>? verses; // не null только для зачал с найденными стихами
  final bool isPericope;

  const CalendarDayPartItem({
    required this.name,
    required this.id,
    required this.content,
    required this.cite,
    required this.description,
    required this.pericopeSource,
    required this.verses,
    required this.isPericope,
  });

  factory CalendarDayPartItem.fromJson(Map<String, dynamic> json) {
    var text = json["text"];
    var pericope = json["pericope"];
    var cite = json["cite"] ?? "";
    var description = json["description"] ?? "";
    if (pericope != null) {
      var rawVerses = pericope["verses"];
      return CalendarDayPartItem(
        name: pericope["label"] ?? pericope["textName"] ?? "",
        id: pericope["textId"],
        content: "",
        cite: cite,
        description: description,
        pericopeSource: pericope["source"],
        verses: rawVerses is List
            ? rawVerses.map((v) => PericopeVerse.fromJson(v)).toList()
            : null,
        isPericope: true,
      );
    }
    return CalendarDayPartItem(
      name: text == null ? "" : (text["name"] ?? ""),
      id: text == null ? null : text["_id"],
      content: text == null ? "" : (text["content"] ?? ""),
      cite: cite,
      description: description,
      pericopeSource: null,
      verses: null,
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
      defaultMemory: json["default"] == null ? null : DayMemory.fromJson(json["default"]),
      secondary: secondaryList is List
          ? secondaryList.map((m) => DayMemory.fromJson(m)).toList()
          : [],
    );
  }

  bool get isEmpty => defaultMemory == null && secondary.isEmpty;
}

class CalendarDay {
  final String name;

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

  final DayMemories memories;

  const CalendarDay({
    required this.name,
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

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    final day = json["day"];
    CalendarDayPart? part(String key) =>
        day == null || day[key] == null ? null : CalendarDayPart.fromJson(day[key]);
    return CalendarDay(
      name: day == null ? "" : (day['name'] ?? ""),
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
      memories: DayMemories.fromJson(json["memories"]),
    );
  }
}
