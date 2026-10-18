library;

/// Уставный день из раздела ordo второй версии API.
///
/// Нам от дня нужно только одно: какие кафизмы читаются по уставу («сегодня»).
/// Прочее в ответе может быть любым — разбор tolerant, незнакомые поля
/// игнорируем. У старого сервера и у дня без данных раздела кафизм нет —
/// это не ошибка, а `kafizmy == null`.

int _asInt(dynamic value) => value is int ? value : int.tryParse("$value") ?? 0;

/// Список чисел, терпимый к мусору: «[2, "3", null]» → [2, 3].
List<int> _intList(dynamic value) {
  if (value is! List) return const <int>[];
  return value
      .map(_asInt)
      .where((number) => number > 0)
      .toList(growable: false);
}

/// Кафизмы уставного дня по службам.
class OrdoKafizmy {
  /// На утрени.
  final List<int> matins;

  /// На вечерне.
  final List<int> vespers;

  /// На часах.
  final List<int> hours;

  /// На полунощнице.
  final List<int> midnight;

  const OrdoKafizmy({
    this.matins = const <int>[],
    this.vespers = const <int>[],
    this.hours = const <int>[],
    this.midnight = const <int>[],
  });

  /// Читается ли кафизма с этим номером сегодня по уставу.
  bool contains(int kathisma) =>
      matins.contains(kathisma) ||
      vespers.contains(kathisma) ||
      hours.contains(kathisma) ||
      midnight.contains(kathisma);

  /// Службы, на которых читается кафизма с этим номером.
  List<String> servicesFor(int kathisma) => <String>[
        if (midnight.contains(kathisma)) "на полунощнице",
        if (matins.contains(kathisma)) "на утрени",
        if (hours.contains(kathisma)) "на часах",
        if (vespers.contains(kathisma)) "на вечерне",
      ];

  bool get isEmpty =>
      matins.isEmpty && vespers.isEmpty && hours.isEmpty && midnight.isEmpty;

  /// Подпись «сегодня по уставу»: «на утрени: 2, 3 · на вечерне: 18».
  /// Пустая строка — кафизм на этот день нет.
  String get label {
    final parts = <String>[
      if (matins.isNotEmpty) "на утрени: ${matins.join(", ")}",
      if (hours.isNotEmpty) "на часах: ${hours.join(", ")}",
      if (vespers.isNotEmpty) "на вечерне: ${vespers.join(", ")}",
      if (midnight.isNotEmpty) "на полунощнице: ${midnight.join(", ")}",
    ];
    return parts.join(" · ");
  }

  factory OrdoKafizmy.fromJson(Map<String, dynamic> json) {
    return OrdoKafizmy(
      matins: _intList(json["matins"]),
      vespers: _intList(json["vespers"]),
      hours: _intList(json["hours"]),
      midnight: _intList(json["midnight"]),
    );
  }
}

/// День раздела ordo. Кафизм у дня может не быть — и это штатно.
class OrdoDay {
  final OrdoKafizmy? kafizmy;

  const OrdoDay({this.kafizmy});

  factory OrdoDay.fromJson(Map<String, dynamic> json) {
    final kafizmy = json["kafizmy"];
    return OrdoDay(
      kafizmy: kafizmy is Map
          ? OrdoKafizmy.fromJson(Map<String, dynamic>.from(kafizmy))
          : null,
    );
  }
}
