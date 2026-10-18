import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/domain/psalter.dart';

// Границы кафизм и статей — порт из typikon-rules (src/psalter.py:69-93), и
// ошибиться в порте просто: число перепутал — и девятнадцатая кафизма
// кончается чужим псалом. Тест держит: покрытие ровно 1–150, у каждой
// кафизмы ровно три статьи, 17-я делится стихами, Пс 151 в кафизмах нет.

void main() {
  group("кафизмы", () {
    test("двадцать кафизм, номера 1–20", () {
      expect(kathismaRanges.keys.toList(),
          List<int>.generate(20, (i) => i + 1));
    });

    test("покрытие ровно Пс 1–150, без дыр и перекрытий", () {
      final covered = <int>{};
      for (final number in kathismaRanges.keys) {
        for (final psalm in kathismaPsalms(number)) {
          expect(covered.add(psalm), isTrue,
              reason: "псалом $psalm вошёл в кафизмы дважды");
        }
      }
      expect(covered.length, 150);
      expect(covered.first, 1);
      expect(covered.last, 150);
    });

    test("Пс 151 в кафизмы не входит, но существует", () {
      for (final number in kathismaRanges.keys) {
        expect(kathismaPsalms(number).contains(psalm151), isFalse);
      }
      expect(psalm151, 151);
      expect(psalm151VerseCount, 7);
      expect(lastPsalm, 150);
    });

    test("границы сверены с оригиналом: первая, шестая и последняя", () {
      // Образец из psalter.py: шестая кафизма — 37–39 / 40–42 / 43–45.
      expect(kathismaRanges[1], (1, 8));
      expect(kathismaRanges[6], (37, 45));
      expect(kathismaRanges[17], (118, 118));
      expect(kathismaRanges[20], (143, 150));
      expect(statiiRanges[6], (39, 42));
    });

    test("не бывает кафизмы вне списка", () {
      expect(isKathismaNumber(0), isFalse);
      expect(isKathismaNumber(21), isFalse);
      expect(kathismaPsalms(21), isEmpty);
      expect(kathismaStatii(21), isEmpty);
    });
  });

  group("статьи", () {
    test("у каждой кафизмы ровно три статьи", () {
      for (final number in kathismaRanges.keys) {
        expect(kathismaStatii(number).length, 3,
            reason: "кафизма $number должна делиться на три статьи");
      }
    });

    test("статьи разбивают кафизму без дыр и перекрытий", () {
      for (final number in kathismaRanges.keys) {
        if (number == 17) continue; // она — стихами, проверена отдельно
        final statii = kathismaStatii(number);
        final joined = <int>[
          for (final statia in statii)
            for (var psalm = statia.firstPsalm;
                psalm <= statia.lastPsalm;
                psalm++)
              psalm,
        ];
        expect(joined, kathismaPsalms(number),
            reason: "статьи кафизмы $number не сходятся с её псалмами");
        for (final statia in statii) {
          expect(statia.isVerseBased, isFalse);
        }
      }
    });

    test("статьи кончаются псалмами из statiiRanges", () {
      for (final entry in statiiRanges.entries) {
        final number = entry.key;
        final statii = kathismaStatii(number);
        expect(statii[0].lastPsalm, entry.value.$1,
            reason: "первая статья кафизмы $number кончается не тем псалмом");
        expect(statii[1].lastPsalm, entry.value.$2,
            reason: "вторая статья кафизмы $number кончается не тем псалмом");
        expect(statii[2].firstPsalm, entry.value.$2 + 1);
        expect(statii[2].lastPsalm, kathismaRanges[number]!.$2);
      }
    });

    test("17-я кафизма — одна 118-я, статьи по стихам", () {
      expect(kathismaPsalms(17), <int>[118]);
      final statii = kathismaStatii(17);
      expect(statii.length, 3);
      expect(statii[0].isVerseBased, isTrue);
      expect((statii[0].firstVerse, statii[0].lastVerse), (1, 72));
      expect((statii[1].firstVerse, statii[1].lastVerse), (73, 131));
      expect((statii[2].firstVerse, statii[2].lastVerse), (132, 176));
    });

    test("разделители статей: после псалмов из statiiRanges, у 17-й — стихов", () {
      for (final entry in statiiRanges.entries) {
        final edges = kathismaBreakEdges(entry.key);
        expect(edges.length, 2);
        expect((edges[0].psalm, edges[1].psalm),
            (entry.value.$1, entry.value.$2));
        expect(edges[0].verse, isNull);
      }
      final edges17 = kathismaBreakEdges(17);
      expect(edges17.length, 2);
      expect((edges17[0].psalm, edges17[0].verse), (118, statii17.$1));
      expect((edges17[1].psalm, edges17[1].verse), (118, statii17.$2));
      expect(statii17, (72, 131));
    });
  });

  group("имена и прогресс", () {
    test("имя кафизмы", () {
      expect(kathismaTitle(1), "1-я кафизма");
      expect(kathismaTitle(2), "2-я кафизма");
      expect(kathismaTitle(5), "5-я кафизма");
      expect(kathismaTitle(17), "17-я кафизма");
      expect(kathismaTitle(20), "20-я кафизма");
    });

    test("ключ и имя записи прогресса", () {
      expect(kathismaProgressId(3), "psalter:kathisma:3");
      expect(kathismaProgressName(3), "Псалтирь: 3-я кафизма");
      expect(kathismaProgressId(psalm151), "psalter:psalm:151");
      expect(kathismaProgressName(psalm151), "Псалтирь: псалом 151");
    });

    test("доля скролла → прочитанные статьи", () {
      expect(statiiRead(0), 0);
      expect(statiiRead(0.1), 0);
      expect(statiiRead(1 / 3), 1);
      expect(statiiRead(0.5), 2);
      expect(statiiRead(0.8), 2);
      expect(statiiRead(0.9), 3);
    });
  });

  group("окончания", () {
    test("формулы не пусты и сверены с источником", () {
      // sync с rules/texts/okonchaniya.yaml (окончание стихословия).
      expect(psalmodyEnd, "Слава, и ныне:");
      expect(statiaBreak, contains("Господи, помилуй (трижды)"));
      expect(statiaBreak, endsWith(psalmodyEnd));
      expect(kathismaEnd, contains("Аллилуия, аллилуия, аллилуия, слава Тебе, Боже (трижды)"));
      expect(kathismaEnd, contains("Господи, помилуй (трижды)"));
    });
  });
}
