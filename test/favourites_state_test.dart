import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/store/models/favourites.dart';

void main() {
  final t0 = DateTime.utc(2026, 8, 25, 10, 0);
  final t1 = DateTime.utc(2026, 8, 25, 10, 1);

  group("отметка", () {
    test("добавляется наверх списка", () {
      final state = const FavouritesState(textIds: ["a"]).toggled("b", at: t0);

      expect(state.textIds, ["b", "a"]);
      expect(state.contains("b"), isTrue);
    });

    test("повторное нажатие снимает", () {
      final state = const FavouritesState(textIds: ["a", "b"]).toggled("a", at: t0);

      expect(state.textIds, ["b"]);
      expect(state.contains("a"), isFalse);
    });

    test("каждое действие попадает в очередь на отправку", () {
      final state = FavouritesState.init().toggled("a", at: t0);

      expect(state.pending.single.textId, "a");
      expect(state.pending.single.isAdd, isTrue);
    });

    test("передумал — в очереди остаётся только итог", () {
      // Иначе сервер получил бы три запроса подряд вместо одного нужного.
      final state = FavouritesState.init()
          .toggled("a", at: t0)
          .toggled("a", at: t0)
          .toggled("a", at: t1);

      expect(state.pending.length, 1);
      expect(state.pending.single.isAdd, isTrue);
      expect(state.pending.single.at, t1);
    });
  });

  group("список с сервера", () {
    test("заменяет локальный", () {
      final state = const FavouritesState(textIds: ["a"]).withServerList(["b", "c"]);

      expect(state.textIds, ["b", "c"]);
    });

    test("не отменяет то, что ещё не доехало", () {
      // Отметка, поставленная в офлайне, иначе мигала бы: пропадала после
      // ответа сервера и возвращалась после отправки очереди.
      final state = FavouritesState.init()
          .toggled("новый", at: t0)
          .withServerList(["a", "b"]);

      expect(state.textIds, ["новый", "a", "b"]);
    });

    test("не возвращает то, что убрали в офлайне", () {
      final state = const FavouritesState(textIds: ["a", "b"])
          .toggled("a", at: t0)
          .withServerList(["a", "b"]);

      expect(state.textIds, ["b"]);
    });
  });

  group("очередь", () {
    test("подтверждённое уходит из очереди", () {
      final state = FavouritesState.init().toggled("a", at: t0);
      final after = state.withoutPending(state.pending);

      expect(after.pending, isEmpty);
      expect(after.textIds, ["a"], reason: "сама отметка остаётся");
    });

    test("переключённое заново во время отправки остаётся в очереди", () {
      // Сравнение идёт вместе с меткой времени, поэтому новая запись по тому же
      // тексту не считается подтверждённой.
      final sent = FavouritesState.init().toggled("a", at: t0).pending;
      final state = FavouritesState.init().toggled("a", at: t1);

      expect(state.withoutPending(sent).pending.single.at, t1);
    });
  });

  group("сохранение между запусками", () {
    test("список и очередь переживают запись и чтение", () {
      final state = const FavouritesState(textIds: ["a"]).toggled("b", at: t0);
      final restored = FavouritesState.fromJson(state.toJson());

      expect(restored.textIds, state.textIds);
      expect(restored.pending, state.pending);
    });

    test("битые записи очереди отбрасываются, остальное читается", () {
      final restored = FavouritesState.fromJson({
        "textIds": ["a", 17, null, "b"],
        "pending": [
          {"textId": "a", "isAdd": true, "at": t0.toIso8601String()},
          {"textId": "b"},
          "мусор",
        ],
      });

      expect(restored.textIds, ["a", "b"]);
      expect(restored.pending.length, 1);
    });

    test("пустое состояние читается без ошибок", () {
      expect(FavouritesState.fromJson(null).textIds, isEmpty);
      expect(FavouritesState.fromJson({}).pending, isEmpty);
    });
  });
}
