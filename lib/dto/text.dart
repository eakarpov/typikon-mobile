import 'dart:convert';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:built_value/serializer.dart';

class Reading {
  final String id;
  final String name;
  final String? author;
  final String readiness;
  final String content;
  final String? ruLink;
  final String? link;
  final String type;
  final DateTime updatedAt;
  final List<String> footnotes;
  final String? dneslovId;
  final String? bookId;
  final String? dayId;
  final bool csSource;
  final bool newUi;

  /// Сколько слов ждут ударения. `null` — текст размечен, показ с ударениями
  /// предлагать нечего.
  final AccentCoverage? accents;

  const Reading({
    required this.id,
    required this.name,
    required this.author,
    required this.content,
    required this.readiness,
    required this.ruLink,
    required this.link,
    required this.type,
    required this.updatedAt,
    required this.footnotes,
    required this.dneslovId,
    required this.bookId,
    required this.dayId,
    required this.csSource,
    required this.newUi,
    this.accents,
  });

  factory Reading.fromJson(Map<String, dynamic> json, Map<String, dynamic>? jsonDay) {
    var serializers = (Serializers().toBuilder()..add(Iso8601DateTimeSerializer())).build();
    var specifiedType = const FullType(DateTime);

    var id = json["id"];
    var name = json["name"];
    var author = json["author"];
    var readiness = json["readiness"];
    var content = json["content"];
    // Вторая версия API переименовала обе ссылки: `ruLink` стал `russianUrl`,
    // `link` — `scanUrl`. Читаем оба имени: в кэше на диске сутки лежат ответы
    // прежней версии, а имена эти ведут к переводу и к скану, то есть к тому,
    // что читатель ищет чаще прочего.
    var ruLink = json["russianUrl"] ?? json["ruLink"];
    var link = json["scanUrl"] ?? json["link"];
    var type = json["type"];
    var dneslovId = json["dneslovId"];
    var updatedAtString = json["updatedAt"];
    var bookId = json["bookId"];
    var csSource = json["csSource"] ?? false;
    var newUi = json["newUi"] ?? false;
    List<String> footnotes = json["footnotes"] == null ? List<String>.empty() : List<String>.from(json["footnotes"] as List);
    var dayId = jsonDay != null ? jsonDay["id"] : null;
    return Reading(
      id: id,
      name: name,
      author: author,
      readiness: readiness,
      content: content,
      ruLink: ruLink,
      link: link,
      type: type,
      updatedAt: (updatedAtString == null) ? DateTime.now() : DateTime.parse(updatedAtString),
      footnotes: footnotes,
      dneslovId: dneslovId,
      bookId: bookId,
      dayId: dayId,
      csSource: csSource,
      newUi: newUi,
      accents: AccentCoverage.fromJson(json["accents"]),
    );
  }
}

class ReadingList {
  final List<Reading> list;

  const ReadingList({
    required this.list,
  });

  /// Конверт второй версии API или голый список первой.
  factory ReadingList.fromJson(dynamic json) {
    final list = json is Map ? (json["items"] as List? ?? const []) : json as List;
    List<Reading> items = List<Reading>.from(
        list
            .map((item) => Reading.fromJson(item, null))
            .toList()
    );
    return ReadingList(
      list: items,
    );
  }
}

/// Текст со знаками, поставленными машиной.
///
/// **Это вид, а не книга.** Корпус остаётся вычитанным; здесь копия, размеченная
/// по словарю собрания, и показывать её надо с прямой пометой об этом. Спорные
/// места разметчик оставляет без знака — потому [marked] и меньше [expected].
class AccentedText {
  final String content;

  /// Сколько знаков поставлено и сколько слов их ждали.
  final int marked;
  final int expected;

  /// По какому собранию считали: `reading` или `chant`. «спасе́» — аорист
  /// чтений, «спа́се» — звательный песнопений, и это не оттенок, а разное слово.
  final String genre;

  const AccentedText({
    required this.content,
    this.marked = 0,
    this.expected = 0,
    this.genre = "reading",
  });

  factory AccentedText.fromJson(Map<String, dynamic> json) => AccentedText(
        content: json["content"] ?? "",
        marked: json["marked"] is int ? json["marked"] : 0,
        expected: json["expected"] is int ? json["expected"] : 0,
        genre: json["genre"] == "chant" ? "chant" : "reading",
      );
}

/// Сколько слов текста ждут ударения и сколько уже несут его в корпусе.
///
/// Приходит с карточкой текста, чтобы экран знал ЗАРАНЕЕ, предлагать ли показ с
/// ударениями. `null` — текст размечен, и переключателя быть не должно вовсе.
class AccentCoverage {
  final int need;
  final int has;

  const AccentCoverage({required this.need, required this.has});

  /// Сколько слов остались без знака в самой книге.
  int get missing => need - has;

  static AccentCoverage? fromJson(dynamic json) {
    if (json is! Map) return null;
    final need = json["need"];
    final has = json["has"];
    if (need is! int || has is! int) return null;
    // Ждущих знака меньше десятка — предлагать нечего: переключатель, меняющий
    // три слова из тысячи, только сбивает.
    if (need - has <= 0) return null;
    return AccentCoverage(need: need, has: has);
  }
}
