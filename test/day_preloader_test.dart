import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/dto/calendar.dart';
import 'package:typikon/utils/day_preloader.dart';

CalendarDayPart _part(List<String?> ids) {
  return CalendarDayPart(
    items: ids
        .map((id) => CalendarDayPartItem(
              name: "Текст",
              id: id,
              content: "",
              cite: "",
              description: "",
              pericopeSource: null,
              verses: null,
              isPericope: false,
            ))
        .toList(),
  );
}

CalendarDay _day({
  CalendarDayPart? kathisma1,
  CalendarDayPart? song3,
  CalendarDayPart? gospelLiturgy,
}) {
  return CalendarDay(
    name: "День",
    vespersProkimenon: null,
    vigil: null,
    kathisma1: kathisma1,
    kathisma2: null,
    kathisma3: null,
    ipakoi: null,
    polyeleos: null,
    song3: song3,
    song6: null,
    gospelMatins: null,
    apolutikaTroparia: null,
    before50: null,
    before1h: null,
    h1: null,
    h3: null,
    h6: null,
    h9: null,
    panagia: null,
    apostleLiturgy: null,
    gospelLiturgy: gospelLiturgy,
    memories: const DayMemories(defaultMemory: null, secondary: []),
  );
}

void main() {
  setUp(resetPreloaderState);

  group("тексты дня", () {
    test("собираются со всех мест службы", () {
      final day = _day(
        kathisma1: _part(["a"]),
        song3: _part(["b"]),
        gospelLiturgy: _part(["c"]),
      );

      expect(day.textIds, ["a", "b", "c"]);
    });

    test("повторы схлопываются", () {
      // Один и тот же текст нередко стоит сразу в нескольких местах службы.
      final day = _day(kathisma1: _part(["a"]), song3: _part(["a", "b"]));

      expect(day.textIds, ["a", "b"]);
    });

    test("места без текстов и зачала без id пропускаются", () {
      final day = _day(kathisma1: _part([null, ""]), song3: _part(["b"]));

      expect(day.textIds, ["b"]);
    });

    test("пустой день не даёт ничего", () {
      expect(_day().textIds, isEmpty);
    });
  });

  group("предзагрузка", () {
    test("проходит по всем текстам", () async {
      final loaded = <String>[];

      await preloadTexts(["a", "b", "c"], fetch: (id) async => loaded.add(id));

      expect(loaded, ["a", "b", "c"]);
    });

    test("не качает больше предела за раз", () async {
      final loaded = <String>[];
      final many = List.generate(60, (i) => "text$i");

      await preloadTexts(many, fetch: (id) async => loaded.add(id));

      expect(loaded.length, maxPreloadedTexts);
    });

    test("повторный заход не тянет уже загруженное", () async {
      final loaded = <String>[];
      Future<void> fetch(String id) async => loaded.add(id);

      await preloadTexts(["a", "b"], fetch: fetch);
      await preloadTexts(["a", "b", "c"], fetch: fetch);

      expect(loaded, ["a", "b", "c"]);
    });

    test("упавший текст не роняет остальные и не считается загруженным", () async {
      final loaded = <String>[];
      Future<void> fetch(String id) async {
        if (id == "b") throw Exception("нет сети");
        loaded.add(id);
      }

      await preloadTexts(["a", "b", "c"], fetch: fetch);
      expect(loaded, ["a", "c"]);

      // "b" не попал в загруженные, поэтому следующая попытка его повторит.
      await preloadTexts(["b"], fetch: (id) async => loaded.add(id));
      expect(loaded, ["a", "c", "b"]);
    });

    test("вторая предзагрузка поверх идущей не запускается", () async {
      final loaded = <String>[];
      final gate = Completer<void>();

      final first = preloadTexts(["a"], fetch: (id) async {
        loaded.add(id);
        await gate.future;
      });
      await preloadTexts(["b"], fetch: (id) async => loaded.add(id));

      expect(loaded, ["a"], reason: "пока идёт первая пачка, вторая ждёт своей очереди");

      gate.complete();
      await first;
    });
  });
}
