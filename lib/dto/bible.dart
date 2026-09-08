import 'pericope.dart';

/// Библия второй версии API.
///
/// Главное здесь — две нумерации на каждом стихе. Каноническая (`chapter`,
/// `verse`) — общий знаменатель всех изданий, ею же названы зачала Типикона;
/// родная (`editionChapter`, `editionVerse`) — как стих напечатан в самой книге.
/// Читающему одно издание вторая не мешает, сводящему издания без первой не
/// обойтись, а ищущему стих в бумажной книге нужна именно родная.

int _asInt(dynamic value) => value is int ? value : int.tryParse("$value") ?? 0;

String _asString(dynamic value) => value is String ? value : "";

/// Издание Библии.
class BibleEdition {
  final String code;
  final String title;

  /// Подпись колонки: «ЦС», «РУМ».
  final String shortTitle;

  /// Начертание: `cu` — церковнославянское, `ro_cyr` — валашская кириллица.
  /// По нему выбирается шрифт, а не по догадке о содержимом.
  final String language;

  /// Язык: `cs`, `ro`, `grc`, `la`, `zh`.
  final String languageCode;

  /// Традиция нумерации; `sla-lxx` — эталон.
  final String versification;

  final int? year;
  final String? sourceUrl;

  const BibleEdition({
    required this.code,
    required this.title,
    required this.shortTitle,
    required this.language,
    required this.languageCode,
    required this.versification,
    this.year,
    this.sourceUrl,
  });

  /// Эталонное издание — то, в чьей нумерации записаны зачала.
  ///
  /// Определяется признаком, а не сравнением с зашитым `cs-eliz`: зашить код
  /// значило бы завести шестую копию списка изданий, и разошлась бы она молча.
  bool get isReference => versification == "sla-lxx";

  factory BibleEdition.fromJson(Map<String, dynamic> json) {
    return BibleEdition(
      code: _asString(json["code"]),
      title: _asString(json["title"]),
      shortTitle: _asString(json["shortTitle"]),
      language: _asString(json["language"]),
      languageCode: _asString(json["languageCode"]),
      versification: _asString(json["versification"]),
      year: json["year"] is int ? json["year"] as int : null,
      sourceUrl: json["sourceUrl"] is String ? json["sourceUrl"] as String : null,
    );
  }
}

class BibleEditionList {
  final List<BibleEdition> list;

  const BibleEditionList(this.list);

  factory BibleEditionList.fromJson(Map<String, dynamic> json) {
    final items = json["items"];
    if (items is! List) return const BibleEditionList([]);
    return BibleEditionList(items
        .whereType<Map>()
        .map((item) => BibleEdition.fromJson(Map<String, dynamic>.from(item)))
        .toList());
  }
}

/// Книга в оглавлении Библии.
class BibleBook {
  /// Он же слаг книги в зачалах: по нему собирается адрес главы.
  final String id;
  final String name;
  final String abbr;

  /// Раздел канона (`pentateuch`… `revelation`) либо `appendix`.
  final String section;

  final bool inCanon;

  /// Сколько в книге канонических глав. `null` у книг приложения: эталон снят с
  /// церковнославянского издания, а их в нём нет вовсе. Ноль сказал бы «глав
  /// нет» — неправда, потому сервер и отдаёт `null`.
  final int? chapters;

  /// Почему книга стоит вне канона; только у приложения.
  final String? note;

  const BibleBook({
    required this.id,
    required this.name,
    required this.abbr,
    required this.section,
    required this.inCanon,
    this.chapters,
    this.note,
  });

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    return BibleBook(
      id: _asString(json["id"]),
      name: _asString(json["name"]),
      abbr: _asString(json["abbr"]),
      section: _asString(json["section"]),
      inCanon: json["inCanon"] == true,
      chapters: json["chapters"] is int ? json["chapters"] as int : null,
      note: json["note"] is String ? json["note"] as String : null,
    );
  }
}

class BibleBookList {
  final List<BibleBook> list;

  const BibleBookList(this.list);

  /// Только канон — то, что показывает оглавление первой итерации.
  List<BibleBook> get canon => list.where((book) => book.inCanon).toList();

  BibleBook? byId(String id) {
    for (final book in list) {
      if (book.id == id) return book;
    }
    return null;
  }

  factory BibleBookList.fromJson(Map<String, dynamic> json) {
    final items = json["items"];
    if (items is! List) return const BibleBookList([]);
    return BibleBookList(items
        .whereType<Map>()
        .map((item) => BibleBook.fromJson(Map<String, dynamic>.from(item)))
        .toList());
  }
}

/// Стих одного издания на одном каноническом месте.
class BibleCell {
  final String id;
  final String canonRef;

  /// Каноническая нумерация — общая для всех изданий.
  final int chapter;
  final int verse;

  /// Родная нумерация — как напечатано в этом издании.
  final int editionChapter;
  final int editionVerse;

  final String content;

  const BibleCell({
    required this.id,
    required this.canonRef,
    required this.chapter,
    required this.verse,
    required this.editionChapter,
    required this.editionVerse,
    required this.content,
  });

  /// Родной номер разошёлся с каноническим — его надо подписать.
  ///
  /// Случай не редкий: в девятом псалме у румынского издания так напечатаны
  /// тридцать восемь стихов из тридцати девяти. По родному номеру стих ищут в
  /// бумажной книге, и подменять его каноническим молча нельзя.
  bool get shifted => editionChapter != chapter || editionVerse != verse;

  /// `null` — издание этого стиха не печатает.
  static BibleCell? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    return BibleCell(
      id: _asString(map["id"]),
      canonRef: _asString(map["canonRef"]),
      chapter: _asInt(map["chapter"]),
      verse: _asInt(map["verse"]),
      editionChapter: _asInt(map["editionChapter"]),
      editionVerse: _asInt(map["editionVerse"]),
      content: _asString(map["content"]),
    );
  }
}

/// Одно каноническое место во всех запрошенных изданиях.
class BibleRow {
  final String canonRef;

  /// Канонический номер стиха.
  final int verse;

  /// По ячейке на издание, в порядке `BibleChapter.editions`.
  ///
  /// `null` значит «издание этого стиха не печатает», и схлопывать его нельзя
  /// ни при каких обстоятельствах: `whereType<BibleCell>()` здесь сдвинет всю
  /// колонку на строку, и заметит это только тот, кто читает оба столбца сразу.
  final List<BibleCell?> cells;

  const BibleRow({
    required this.canonRef,
    required this.verse,
    required this.cells,
  });

  factory BibleRow.fromJson(Map<String, dynamic> json) {
    final editions = json["editions"];
    return BibleRow(
      canonRef: _asString(json["canonRef"]),
      verse: _asInt(json["verse"]),
      cells: editions is List
          ? editions.map(BibleCell.fromJson).toList()
          : const <BibleCell?>[],
    );
  }
}

/// Глава Библии в одном или нескольких изданиях.
class BibleChapter {
  /// Книга, как её назвал сервер.
  ///
  /// Имя берётся отсюда, а не из оглавления: тогда незнакомый идентификатор не
  /// роняет экран и не показывает «Без названия» — он лишь лишает сетки глав и
  /// перехода к соседней книге.
  final BibleBook book;

  final int chapter;

  /// Порядок изданий — он же порядок ячеек в каждой строке.
  final List<BibleEdition> editions;

  final List<BibleRow> rows;

  const BibleChapter({
    required this.book,
    required this.chapter,
    required this.editions,
    required this.rows,
  });

  /// Колонка одного издания списком — мост к готовому `VerseListView`.
  ///
  /// Пустые ячейки здесь отбрасываются, и это правильно ровно в одиночном виде:
  /// показывать «стиха нет» в сплошном тексте одного издания нечего и незачем.
  /// В параллельном виде так делать нельзя — там пропуск обязан быть виден.
  ///
  /// Цена перехода в [PericopeVerse] — родная нумерация теряется: он знает
  /// только главу, стих и содержимое. Для эталона потери нет, для прочих есть,
  /// и до своего рендера она возмещается подписью под главой.
  List<PericopeVerse> versesFor(int column) {
    final verses = <PericopeVerse>[];
    for (final row in rows) {
      if (column < 0 || column >= row.cells.length) continue;
      final cell = row.cells[column];
      if (cell == null) continue;
      verses.add(PericopeVerse(
        chapter: cell.chapter,
        verse: cell.verse,
        content: cell.content,
      ));
    }
    return verses;
  }

  factory BibleChapter.fromJson(Map<String, dynamic> json) {
    final book = json["book"];
    final editions = json["editions"];
    final verses = json["verses"];

    return BibleChapter(
      book: book is Map
          ? BibleBook.fromJson(Map<String, dynamic>.from(book))
          : const BibleBook(id: "", name: "", abbr: "", section: "", inCanon: true),
      chapter: _asInt(json["chapter"]),
      editions: editions is List
          ? editions
              .whereType<Map>()
              .map((item) => BibleEdition.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const <BibleEdition>[],
      rows: verses is List
          ? verses
              .whereType<Map>()
              .map((item) => BibleRow.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const <BibleRow>[],
    );
  }
}
