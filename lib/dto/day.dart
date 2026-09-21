import 'package:typikon/dto/pericope.dart';

export 'package:typikon/dto/pericope.dart';

class DayTextBook {
  final String id;
  final String name;

  const DayTextBook({
    required this.id,
    required this.name,
  });

  factory DayTextBook.fromJson(Map<String, dynamic> json) {
    return DayTextBook(
      // То же переименование, что и в calendar.dart: сперва `id`.
      id: json["id"] ?? json["_id"] ?? "",
      name: json["name"] ?? "",
    );
  }
}

class DayText {
  final String id;
  final String name;
  final String content;
  final DayTextBook? book;
  final bool csSource;

  const DayText({
    required this.id,
    required this.name,
    required this.content,
    required this.book,
    required this.csSource,
  });

  factory DayText.fromJson(Map<String, dynamic> json) {
    return DayText(
      id: json["id"] ?? json["_id"] ?? "",
      name: json["name"] ?? "",
      // Тело приходит только по просьбе (`expand=content`). Пустое означает,
      // что его не просили, — не то, что текст пуст.
      content: json["content"] ?? "",
      book: json["book"] == null ? null : DayTextBook.fromJson(json["book"]),
      csSource: json["csSource"] ?? false,
    );
  }
}

class DayTextsPart {
  final DayText? text;
  final int? statia;

  /// Зачало вместо своего текста: Евангелие, Апостол и паремии сервер отдаёт
  /// ссылкой на книгу Библии с границами и уже вынутыми стихами.
  final Pericope? pericope;
  final String cite;
  final String description;

  const DayTextsPart({
    required this.text,
    required this.statia,
    this.pericope,
    this.cite = "",
    this.description = "",
  });

  bool get isPericope => pericope != null;

  factory DayTextsPart.fromJson(Map<String, dynamic> json) {
    final rawText = json["text"];
    // Вторая версия API на месте отсутствующего текста присылает `null`; первая
    // клала заглушку `{"_id": null}`. Различаем по наличию опознавателя, а не по
    // наличию поля — так верно для обеих.
    final hasText = rawText is Map<String, dynamic> &&
        (rawText["id"] != null || rawText["_id"] != null);
    var statiaVal = json["statia"] == null ? null : json["statia"];
    return DayTextsPart(
      text: hasText ? DayText.fromJson(rawText) : null,
      statia: statiaVal,
      pericope: Pericope.fromJson(json["pericope"]),
      cite: json["cite"] ?? "",
      description: json["description"] ?? "",
    );
  }
}

class DayTextsParts {
  final List<DayTextsPart>? items;

  const DayTextsParts({
    required this.items,
  });

  factory DayTextsParts.fromJson(Map<String, dynamic> json) {
    var list = json['items'] == null ? [] : json['items'];
    List<DayTextsPart> items = List<DayTextsPart>.from(
        list
            .map((item) => DayTextsPart.fromJson(item))
            .toList()
    );

    return DayTextsParts(
      items: items,
    );
  }
}

/// Место службы: заголовок и то, что в нём читается.
///
/// **Заголовок приходит с сервера, а не составляется здесь.** Прежде этот
/// список — двадцать мест с русскими подписями — был зашит в экран дня, и вторым
/// таким же списком жил сервер. Два списка, писанные руками и не знающие друг о
/// друге, разошлись: у сервера недоставало двух мест, и Великий пяток показывал
/// семь чтений из девяти. Теперь список один, и он там, где данные.
class DaySection {
  /// Имя поля в базе: `song6`, `gospelLiturgy`. Наружу не показывается, но по
  /// нему удобно отличать места службы в отладке.
  final String slot;

  final String title;
  final List<DayTextsPart> items;

  const DaySection({required this.slot, required this.title, this.items = const []});

  factory DaySection.fromJson(Map<String, dynamic> json) => DaySection(
        slot: json["slot"] ?? "",
        title: json["title"] ?? "",
        items: json["items"] is List
            ? (json["items"] as List)
                .whereType<Map>()
                .map((item) => DayTextsPart.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const <DayTextsPart>[],
      );
}

class DayTexts {
  final String? id;
  final String? alias;
  final String? name;

  /// Места службы по порядку, и только непустые: сервер пустых не присылает.
  final List<DaySection> readings;

  const DayTexts({
    required this.id,
    required this.name,
    this.alias,
    this.readings = const [],
  });

  factory DayTexts.fromJson(Map<String, dynamic> json) => DayTexts(
        id: json["id"],
        alias: json["alias"],
        name: json["name"],
        readings: json["readings"] is List
            ? (json["readings"] as List)
                .whereType<Map>()
                .map((item) => DaySection.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const <DaySection>[],
      );
}
