// Зачин — первые шесть слов песнопения, приведённые к общему виду.
//
// Своего идентификатора у зачина нет: ключ и есть идентификатор, притом
// читаемый. По нему песнопение узнаётся так же, как узнают его на клиросе, —
// по первым словам, а не по номеру.

int _asInt(dynamic value) => value is int ? value : int.tryParse("$value") ?? 0;

int? _asIntOrNull(dynamic value) => value is int ? value : int.tryParse("$value");

String _asString(dynamic value) => value is String ? value : "";

String? _asStringOrNull(dynamic value) =>
    value is String && value.isNotEmpty ? value : null;

/// Строка указателя: ключ, сколько раз встречается и одно представительное.
class Incipit {
  final String incipit;
  final String language;

  /// Сколько песнопений начинается этими словами.
  final int uses;

  /// Строка песнопения, взятая как образец. Она же — мост в поиск по
  /// песнопениям: это настоящий идентификатор строки корпуса.
  final int? sampleId;

  /// Текст образца — с ударениями, как напечатан.
  final String text;

  final String? unit;
  final String? book;
  final String? memory;
  final String? akathist;

  const Incipit({
    required this.incipit,
    required this.language,
    required this.uses,
    required this.text,
    this.sampleId,
    this.unit,
    this.book,
    this.memory,
    this.akathist,
  });

  factory Incipit.fromJson(Map<String, dynamic> json) => Incipit(
        incipit: _asString(json["incipit"]),
        language: _asString(json["language"]),
        uses: _asInt(json["uses"]),
        text: _asString(json["text"]),
        sampleId: _asIntOrNull(json["sampleId"]),
        unit: _asStringOrNull(json["unit"]),
        book: _asStringOrNull(json["book"]),
        memory: _asStringOrNull(json["memory"]),
        akathist: _asStringOrNull(json["akathist"]),
      );
}

/// Вхождение зачина: где именно это песнопение стоит в службе.
class IncipitWitness {
  final int id;
  final String? unit;
  final int? ode;
  final int? stanza;
  final int? tone;
  final String? service;
  final String? position;
  final String? memory;
  final String? book;
  final int? month;
  final int? day;
  final String? akathist;

  const IncipitWitness({
    required this.id,
    this.unit,
    this.ode,
    this.stanza,
    this.tone,
    this.service,
    this.position,
    this.memory,
    this.book,
    this.month,
    this.day,
    this.akathist,
  });

  factory IncipitWitness.fromJson(Map<String, dynamic> json) => IncipitWitness(
        id: _asInt(json["id"]),
        unit: _asStringOrNull(json["unit"]),
        ode: _asIntOrNull(json["ode"]),
        stanza: _asIntOrNull(json["stanza"]),
        tone: _asIntOrNull(json["tone"]),
        service: _asStringOrNull(json["service"]),
        position: _asStringOrNull(json["position"]),
        memory: _asStringOrNull(json["memory"]),
        book: _asStringOrNull(json["book"]),
        month: _asIntOrNull(json["month"]),
        day: _asIntOrNull(json["day"]),
        akathist: _asStringOrNull(json["akathist"]),
      );
}

/// То же песнопение на другом языке.
class IncipitCorrespondence {
  final String language;
  final String text;
  final String incipit;

  /// Чем связь установлена: `edition` — так напечатано в издании,
  /// `structure` — совпало место в службе.
  final String? method;

  /// `certain` или `candidate`.
  final String? confidence;

  /// Основание словами — то, что позволяет читателю проверить нас.
  final String? evidence;

  const IncipitCorrespondence({
    required this.language,
    required this.text,
    required this.incipit,
    this.method,
    this.confidence,
    this.evidence,
  });

  factory IncipitCorrespondence.fromJson(Map<String, dynamic> json) =>
      IncipitCorrespondence(
        language: _asString(json["language"]),
        text: _asString(json["text"]),
        incipit: _asString(json["incipit"]),
        method: _asStringOrNull(json["method"]),
        confidence: _asStringOrNull(json["confidence"]),
        evidence: _asStringOrNull(json["evidence"]),
      );
}

/// Карточка зачина: все вхождения и соответствия на другие языки.
class IncipitDetail {
  final String incipit;
  final String language;
  final int uses;
  final String text;

  /// Текст не свой: подтянут по ссылке из Ирмология или соседнего канона.
  final bool borrowed;

  final List<IncipitWitness> witnesses;

  /// Заявленные издателем и предположенные нами — **раздельно**.
  ///
  /// Схлопывать их в одно «перевод» нельзя. `declared` утверждает издатель;
  /// `supposed` — наша догадка по совпавшему месту службы, и в корпусе рядом с
  /// ней записан живой ложноположительный пример. Спрятав разницу, мы
  /// переложили бы свою неуверенность на читателя молча.
  final List<IncipitCorrespondence> declared;
  final List<IncipitCorrespondence> supposed;

  const IncipitDetail({
    required this.incipit,
    required this.language,
    required this.uses,
    required this.text,
    required this.borrowed,
    required this.witnesses,
    required this.declared,
    required this.supposed,
  });

  bool get hasCorrespondences => declared.isNotEmpty || supposed.isNotEmpty;

  static List<IncipitCorrespondence> _correspondences(dynamic list) => list is List
      ? list
          .whereType<Map>()
          .map((row) => IncipitCorrespondence.fromJson(Map<String, dynamic>.from(row)))
          .toList()
      : const [];

  factory IncipitDetail.fromJson(Map<String, dynamic> json) {
    final witnesses = json["witnesses"];
    final correspondences = json["correspondences"];
    final map = correspondences is Map
        ? Map<String, dynamic>.from(correspondences)
        : const <String, dynamic>{};

    return IncipitDetail(
      incipit: _asString(json["incipit"]),
      language: _asString(json["language"]),
      uses: _asInt(json["uses"]),
      text: _asString(json["text"]),
      borrowed: json["borrowed"] == true,
      witnesses: witnesses is List
          ? witnesses
              .whereType<Map>()
              .map((row) => IncipitWitness.fromJson(Map<String, dynamic>.from(row)))
              .toList()
          : const [],
      declared: _correspondences(map["declared"]),
      supposed: _correspondences(map["supposed"]),
    );
  }
}
