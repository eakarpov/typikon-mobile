/// Конверт коллекции второй версии API: `{items, total, limit, offset}`.
///
/// Заведён общим, потому что конверт у v2 один на все списки, а листают его уже
/// три ручки. Разбирать его в каждой по-своему значило бы трижды написать одну и
/// ту же арифметику «есть ли ещё» — и трижды иметь шанс ошибиться на границе
/// последней страницы.
class Paged<T> {
  final List<T> items;
  final int total;
  final int limit;
  final int offset;

  const Paged({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  const Paged.empty()
      : items = const [],
        total = 0,
        limit = 0,
        offset = 0;

  /// Есть ли что просить дальше.
  ///
  /// Считаем по числу уже полученного, а не по `offset + limit`: сервер вправе
  /// отдать меньше запрошенного, и тогда счёт по `limit` перепрыгнул бы через
  /// хвост выдачи. Пустая страница — тоже конец, даже если `total` говорит иначе:
  /// иначе список крутил бы запросы до бесконечности.
  bool get hasMore => items.isNotEmpty && offset + items.length < total;

  static int _asInt(dynamic value) => value is int ? value : int.tryParse("$value") ?? 0;

  static Paged<T> fromJson<T>(
    dynamic json,
    T Function(Map<String, dynamic> item) item,
  ) {
    if (json is! Map) return Paged<T>.empty();

    final items = json["items"];
    if (items is! List) return Paged<T>.empty();

    return Paged<T>(
      items: items
          .whereType<Map>()
          .map((row) => item(Map<String, dynamic>.from(row)))
          .toList(),
      total: _asInt(json["total"]),
      limit: _asInt(json["limit"]),
      offset: _asInt(json["offset"]),
    );
  }
}
