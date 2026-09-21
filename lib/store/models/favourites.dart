import 'package:flutter/foundation.dart';

/// Избранное пользователя.
///
/// До этого список лежал прямо в SharedPreferences и читался из двух мест —
/// со страницы текста и со страницы избранного, — которые друг о друге не
/// знали и расходились, пока экран не перезапросишь. Теперь список один, в
/// сторе, а хранилище и сервер — то, куда он сохраняется.
///
/// Работает без аккаунта: избранное — не премиальная возможность. Вошедшему
/// тот же список синхронизируется с сервером.

/// Отложенное изменение: отметка ставится сразу, а до сервера доезжает, когда
/// появится сеть.
@immutable
class PendingFavourite {
  final String textId;

  /// true — добавить, false — убрать.
  final bool isAdd;

  /// Когда пользователь это сделал. Нужно, чтобы при конфликте побеждало
  /// последнее по времени действие, а не последнее доехавшее.
  final DateTime at;

  const PendingFavourite({
    required this.textId,
    required this.isAdd,
    required this.at,
  });

  @override
  int get hashCode => textId.hashCode ^ isAdd.hashCode ^ at.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PendingFavourite &&
              textId == other.textId &&
              isAdd == other.isAdd &&
              at == other.at;

  @override
  String toString() => 'PendingFavourite{textId: $textId, isAdd: $isAdd, at: $at}';

  Map<String, dynamic> toJson() => {
        'textId': textId,
        'isAdd': isAdd,
        'at': at.toIso8601String(),
      };

  static PendingFavourite? fromJson(dynamic json) {
    if (json is! Map) return null;
    final textId = json['textId'];
    final isAdd = json['isAdd'];
    final at = DateTime.tryParse(json['at']?.toString() ?? '');
    if (textId is! String || textId.isEmpty || isAdd is! bool || at == null) return null;
    return PendingFavourite(textId: textId, isAdd: isAdd, at: at);
  }
}

@immutable
class FavouritesState {
  /// Идентификаторы текстов, новые сверху — в том же порядке, в каком их
  /// отдаёт сервер.
  final List<String> textIds;

  /// Изменения, ещё не доехавшие до сервера.
  final List<PendingFavourite> pending;

  const FavouritesState({
    this.textIds = const [],
    this.pending = const [],
  });

  factory FavouritesState.init() => const FavouritesState();

  bool contains(String textId) => textIds.contains(textId);

  FavouritesState copyWith({
    List<String>? textIds,
    List<PendingFavourite>? pending,
  }) {
    return FavouritesState(
      textIds: textIds ?? this.textIds,
      pending: pending ?? this.pending,
    );
  }

  /// Отметка снимается или ставится мгновенно, а изменение кладётся в очередь.
  ///
  /// В очереди по каждому тексту остаётся только последнее действие: если
  /// человек передумал трижды, серверу незачем знать про все три раза, ему
  /// нужен итог.
  FavouritesState toggled(String textId, {required DateTime at}) {
    final isAdd = !contains(textId);
    final nextIds = isAdd
        ? [textId, ...textIds]
        : textIds.where((id) => id != textId).toList();

    return FavouritesState(
      textIds: nextIds,
      pending: [
        ...pending.where((p) => p.textId != textId),
        PendingFavourite(textId: textId, isAdd: isAdd, at: at),
      ],
    );
  }

  /// Список, пришедший с сервера, поверх которого остаются ещё не доехавшие
  /// изменения — иначе отметка, сделанная в офлайне, мигала бы: пропадала
  /// после ответа сервера и возвращалась после отправки очереди.
  FavouritesState withServerList(List<String> serverIds) {
    final result = <String>[...serverIds];
    for (final change in pending) {
      result.remove(change.textId);
      if (change.isAdd) result.insert(0, change.textId);
    }
    return copyWith(textIds: result);
  }

  /// Убирает из очереди то, что подтверждено сервером. Сравнение полное, вместе
  /// с меткой времени: если во время отправки пользователь переключил ту же
  /// отметку заново, новая запись обязана остаться в очереди.
  FavouritesState withoutPending(List<PendingFavourite> confirmed) {
    return copyWith(
      pending: pending.where((p) => !confirmed.contains(p)).toList(),
    );
  }

  @override
  int get hashCode => Object.hashAll([...textIds, ...pending]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is FavouritesState &&
              _sameList(textIds, other.textIds) &&
              _sameList(pending, other.pending);

  static bool _sameList(List a, List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'FavouritesState{textIds: $textIds, pending: $pending}';

  Map<String, dynamic> toJson() => {
        'textIds': textIds,
        'pending': pending.map((p) => p.toJson()).toList(),
      };

  static FavouritesState fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FavouritesState();
    final ids = json['textIds'];
    final pending = json['pending'];
    return FavouritesState(
      textIds: ids is List ? ids.whereType<String>().toList() : const [],
      pending: pending is List
          ? pending.map(PendingFavourite.fromJson).whereType<PendingFavourite>().toList()
          : const [],
    );
  }
}
