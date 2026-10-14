/// Согласование нумераций: где канонический стих стоит в каждом издании.
///
/// Ответ ручки `/api/v2/concordance`. Адрес (`canonRef`) — канонический, в
/// счёте эталонного издания; места внутри изданий напечатаны в собственном
/// счёте каждого издания: одному каноническому стиху у румынской Псалтири
/// отвечает «9:12», а разорванный надвое стих даёт в одном издании два места.
library;

int _asInt(dynamic value) => value is int ? value : int.tryParse("$value") ?? 0;

String _asString(dynamic value) => value is String ? value : "";

/// Место стиха в одном издании — в собственном счёте этого издания.
class ConcordancePlace {
  /// Книга в счёте издания.
  final String book;
  final int chapter;
  final int verse;

  const ConcordancePlace({
    required this.book,
    required this.chapter,
    required this.verse,
  });

  factory ConcordancePlace.fromJson(Map<String, dynamic> json) {
    return ConcordancePlace(
      book: _asString(json["book"]),
      chapter: _asInt(json["chapter"]),
      verse: _asInt(json["verse"]),
    );
  }
}

/// Где стоит один и тот же канонический стих в одном издании.
class ConcordanceEdition {
  /// Код издания; человеческое имя для него резолвится по `/bible/editions`.
  final String edition;

  /// Книга издания, в которой напечатан этот стих.
  final String book;

  /// Одно место, два (стих разорван надвое) или ни одного (не печатается —
  /// тогда издание в ответе вовсе не приходит).
  final List<ConcordancePlace> places;

  const ConcordanceEdition({
    required this.edition,
    required this.book,
    required this.places,
  });

  factory ConcordanceEdition.fromJson(Map<String, dynamic> json) {
    final places = json["places"];
    return ConcordanceEdition(
      edition: _asString(json["edition"]),
      book: _asString(json["book"]),
      places: places is List
          ? places
              .whereType<Map>()
              .map((item) => ConcordancePlace.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const <ConcordancePlace>[],
    );
  }
}

class Concordance {
  /// Канонический адрес стиха — обычно тем же текстом, что и запрошенный.
  final String canonRef;

  /// По изданию собрания — где в нём стоит этот стих.
  final List<ConcordanceEdition> editions;

  const Concordance({
    required this.canonRef,
    required this.editions,
  });

  factory Concordance.fromJson(Map<String, dynamic> json) {
    final editions = json["editions"];
    return Concordance(
      canonRef: _asString(json["canonRef"]),
      editions: editions is List
          ? editions
              .whereType<Map>()
              .map((item) => ConcordanceEdition.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const <ConcordanceEdition>[],
    );
  }
}
