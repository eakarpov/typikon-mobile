/// Зачало — отрезок библейской книги, назначенный Уставом на службу.
///
/// Бекенд отдаёт его в двух видах сразу: [Pericope.ranges] — границы
/// (с какой главы и стиха по какие), [Pericope.verses] — уже вынутые стихи.
/// Границы нужны не только для показа: по ним полный текст книги подсвечивает,
/// где зачало начинается и где кончается.
class PericopeVerse {
  final int chapter;
  final int verse;
  final String content;

  const PericopeVerse({
    required this.chapter,
    required this.verse,
    required this.content,
  });

  static int _asInt(dynamic value) =>
      value is int ? value : int.tryParse("$value") ?? 0;

  factory PericopeVerse.fromJson(Map<String, dynamic> json) {
    return PericopeVerse(
      chapter: _asInt(json["chapter"]),
      verse: _asInt(json["verse"]),
      content: json["content"] ?? "",
    );
  }
}

class PericopeRange {
  final int chapterFrom;
  final int verseFrom;
  final int chapterTo;
  final int verseTo;

  const PericopeRange({
    required this.chapterFrom,
    required this.verseFrom,
    required this.chapterTo,
    required this.verseTo,
  });

  factory PericopeRange.fromJson(Map<String, dynamic> json) {
    return PericopeRange(
      chapterFrom: PericopeVerse._asInt(json["chapterFrom"]),
      verseFrom: PericopeVerse._asInt(json["verseFrom"]),
      chapterTo: PericopeVerse._asInt(json["chapterTo"]),
      verseTo: PericopeVerse._asInt(json["verseTo"]),
    );
  }

  /// Внутри ли стих отрезка. Отрезок может пересекать границу глав, поэтому
  /// сравниваем пару (глава, стих) как одно число.
  bool contains(int chapter, int verse) {
    final point = chapter * 1000 + verse;
    return point >= chapterFrom * 1000 + verseFrom && point <= chapterTo * 1000 + verseTo;
  }

  /// Ссылка на отрезок обычными словами: "гл. 6, ст. 31–34".
  String get label {
    if (chapterFrom == chapterTo) {
      final verses = verseFrom == verseTo ? "$verseFrom" : "$verseFrom–$verseTo";
      return "гл. $chapterFrom, ст. $verses";
    }
    return "гл. $chapterFrom, ст. $verseFrom — гл. $chapterTo, ст. $verseTo";
  }
}

/// Ссылка на зачало вместе с уже резолвленными стихами.
class Pericope {
  final String? id;
  final String? source; // "gospel" | "apostle" | "paremia"
  final String label; // "Мф. 19"
  /// Идентификатор книги в каноне — он же адрес книги в разделе Библии.
  ///
  /// По нему открывается глава: `bookSlug` + границы дают всё, что нужно, и
  /// ничего сверх того.
  final String? bookSlug;

  /// Книга издания, из которой собрано чтение.
  ///
  /// Прежде это был `texts._id`, и по нему открывалась страница чтения. С
  /// переездом Библии на свою модель это `bible_books._id`: в коллекции текстов
  /// такого документа больше нет, и `/api/v1/texts/{id}` отвечает на него
  /// двумястами с пустым телом. Открывать по нему нельзя — только показывать.
  final String? textId;
  final String? textName;
  final List<PericopeRange> ranges;
  final List<PericopeVerse> verses;

  const Pericope({
    required this.id,
    required this.source,
    required this.label,
    required this.bookSlug,
    required this.textId,
    required this.textName,
    required this.ranges,
    required this.verses,
  });

  static Pericope? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final rawRanges = json["ranges"];
    final rawVerses = json["verses"];
    return Pericope(
      id: json["id"] ?? json["_id"],
      source: json["source"],
      label: json["label"] ?? json["textName"] ?? "",
      bookSlug: json["bookSlug"],
      textId: json["textId"],
      textName: json["textName"],
      ranges: rawRanges is List
          ? rawRanges.map<PericopeRange>((r) => PericopeRange.fromJson(r)).toList()
          : const [],
      verses: rawVerses is List
          ? rawVerses.map<PericopeVerse>((v) => PericopeVerse.fromJson(v)).toList()
          : const [],
    );
  }
}
