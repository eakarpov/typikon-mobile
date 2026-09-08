import "package:typikon/dto/day.dart";

class WeekWithDays {
  final String? id;
  final String? type;
  final String? label;
  final int? value;
  final String? alias;
  final bool? penticostration;
  final List<DayTexts> days;

  const WeekWithDays({
    required this.id,
    required this.type,
    required this.value,
    required this.label,
    required this.alias,
    required this.penticostration,
    required this.days,
  });

  /// Дней в перечне седмиц нет — там только их число; они приезжают с карточкой
  /// седмицы. Пустой список здесь означает «ещё не спрашивали», а не «дней нет».
  factory WeekWithDays.fromJson(Map<String, dynamic> json) {
    final raw = json["days"];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => DayTexts.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : const <DayTexts>[];

    return WeekWithDays(
      id: json["id"],
      value: json["value"],
      alias: json["alias"],
      label: json["label"],
      type: json["type"],
      // Вторая версия API исправила опечатку первой: было `penticostration`,
      // стало `penticostarion`. Читаем оба написания.
      penticostration: json["penticostarion"] ?? json["penticostration"],
      days: items,
    );
  }
}
