library;

/// Последование молитвослова — разобранное на ряды: молитва, рубрика,
/// указание о поклоне.
///
/// Ручка `/api/v2/posledovanie` отдаёт богослужебный текст по ключу
/// (`na-son`, `ko-prichashcheniyu` и проч.). Ответ книжный и зеркалит печатный
/// источник: у ряда есть заголовок ([PosledovanieRow.label]), лицо, от которого
/// он говорится ([PosledovanieRow.lead]), сам текст, рубрика-курсив ([note])
/// и указание «с поклоном» ([poklon]). Разбор tolerant, как у ордо
/// (`lib/dto/ordo.dart`): незнакомые поля игнорируем, а не падаем — руку в
/// открытой зоне сервер правит чаще, чем приложение.

class PosledovanieRow {
  /// Заголовок ряда, как в книге: «Моли́тва 1-я, свята́го Макси́ма».
  final String? label;

  /// Лицо, от которого говорится ряд: «Иере́й», «Чте́ц», «Молящийся».
  final String? lead;

  /// «По 3» — сколько раз повторяется текст.
  final int? repeatCount;

  /// Указание книги сделать поклон: сей поклон или земной. В ответе может
  /// прийти и строкой, и булевым — годным считаем любое непустое значение.
  final bool poklon;

  /// Рубрика: курсивное пояснение из книги («И поклоня́ются до земли́»).
  final String? note;

  final String text;

  const PosledovanieRow({
    this.label,
    this.lead,
    this.repeatCount,
    this.poklon = false,
    this.note,
    this.text = "",
  });

  factory PosledovanieRow.fromJson(Map<String, dynamic> json) {
    final rawRepeat = json["repeatCount"];
    final rawPoklon = json["poklon"];

    return PosledovanieRow(
      label: json["label"] is String ? json["label"] as String : null,
      lead: json["lead"] is String ? json["lead"] as String : null,
      repeatCount: rawRepeat is int
          ? rawRepeat
          : int.tryParse("$rawRepeat"),
      poklon: rawPoklon is bool
          ? rawPoklon
          : rawPoklon is num
              ? rawPoklon != 0
              : rawPoklon is String && rawPoklon.isNotEmpty,
      note: json["note"] is String ? json["note"] as String : null,
      text: json["text"] is String ? json["text"] as String : "",
    );
  }
}

/// Последование целиком — ключ, язык и ряды в книжном порядке.
class Posledovanie {
  final String key;
  final String lang;
  final List<PosledovanieRow> rows;

  const Posledovanie({
    this.key = "",
    this.lang = "",
    this.rows = const <PosledovanieRow>[],
  });

  factory Posledovanie.fromJson(Map<String, dynamic> json) {
    final rawRows = json["rows"];
    return Posledovanie(
      key: json["key"] is String ? json["key"] as String : "",
      lang: json["lang"] is String ? json["lang"] as String : "",
      rows: rawRows is List
          ? rawRows
              .whereType<Map>()
              .map((row) => PosledovanieRow.fromJson(Map<String, dynamic>.from(row)))
              .toList()
          : const <PosledovanieRow>[],
    );
  }
}
