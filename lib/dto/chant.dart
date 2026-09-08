// Песнопение книги на своём месте службы.
//
// Другой корпус, нежели поиск по библиотеке: там книги целиком, здесь службы,
// разобранные по позициям — стихира, седален, тропарь, ирмос, каждое со своим
// местом. Складывать их в одну выдачу нечестно, у них разные единицы.

int? _asIntOrNull(dynamic value) => value is int ? value : int.tryParse("$value");

String _asString(dynamic value) => value is String ? value : "";

String? _asStringOrNull(dynamic value) =>
    value is String && value.isNotEmpty ? value : null;

/// Кусок найденного фрагмента: текст и признак, попал ли он под запрос.
///
/// Сервер отдаёт фрагмент уже разобранным на куски, а не размеченным внутри
/// строки. Это удобнее, чем кажется: нам не приходится ни искать подстроку (её
/// не найти — ищется нормализованная форма, а показывается исходная, с
/// ударениями), ни разбирать чужую разметку.
class SnippetPart {
  final String text;
  final bool hit;

  const SnippetPart({required this.text, required this.hit});

  factory SnippetPart.fromJson(Map<String, dynamic> json) => SnippetPart(
        text: _asString(json["text"]),
        hit: json["hit"] == true,
      );
}

class Chant {
  final int id;
  final List<SnippetPart> snippet;

  /// Язык: `cu_gr`, `ro`, `grc`, `en`. Корпус четырёхъязычный, и без этого
  /// поля славянскую стихиру не отличить от румынской.
  final String? language;

  /// Род песнопения: `stichera`, `sedalen`, `troparion`, `irmos`…
  final String? unit;

  /// Где это поётся.
  final String? memory;
  final String? book;
  final int? month;
  final int? day;
  final String? service;
  final String? position;
  final int? tone;

  /// У строфы акафиста нет ни книги, ни дня: её адрес — имя произведения и
  /// номер строфы.
  final String? akathist;
  final int? stanza;

  const Chant({
    required this.id,
    required this.snippet,
    this.language,
    this.unit,
    this.memory,
    this.book,
    this.month,
    this.day,
    this.service,
    this.position,
    this.tone,
    this.akathist,
    this.stanza,
  });

  /// Строка с текстом фрагмента без разметки — для тех мест, где спанов не надо.
  String get plainText => snippet.map((part) => part.text).join();

  factory Chant.fromJson(Map<String, dynamic> json) {
    final snippet = json["snippet"];
    return Chant(
      id: _asIntOrNull(json["id"]) ?? 0,
      snippet: snippet is List
          ? snippet
              .whereType<Map>()
              .map((part) => SnippetPart.fromJson(Map<String, dynamic>.from(part)))
              .toList()
          : const [],
      language: _asStringOrNull(json["language"]),
      unit: _asStringOrNull(json["unit"]),
      memory: _asStringOrNull(json["memory"]),
      book: _asStringOrNull(json["book"]),
      month: _asIntOrNull(json["month"]),
      day: _asIntOrNull(json["day"]),
      service: _asStringOrNull(json["service"]),
      position: _asStringOrNull(json["position"]),
      tone: _asIntOrNull(json["tone"]),
      akathist: _asStringOrNull(json["akathist"]),
      stanza: _asIntOrNull(json["stanza"]),
    );
  }
}
