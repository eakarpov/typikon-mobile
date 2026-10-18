import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/api/ordo.dart';
import 'package:typikon/dto/ordo.dart';

// Разбор дня раздела ordo tolerant: у старого сервера и у дня без данных
// раздела кафизм нет — это штатный null, а не ошибка.

void main() {
  group("OrdoKafizmy", () {
    test("разбор кафизм по службам", () {
      final kafizmy = OrdoKafizmy.fromJson(<String, dynamic>{
        "matins": <int>[2, 3],
        "vespers": <int>[18],
        "hours": <int>[],
        "midnight": <int>[],
      });

      expect(kafizmy.matins, <int>[2, 3]);
      expect(kafizmy.vespers, <int>[18]);
      expect(kafizmy.hours, isEmpty);
      expect(kafizmy.midnight, isEmpty);
    });

    test("подпись «сегодня»: только непустые службы", () {
      const kafizmy = OrdoKafizmy(matins: <int>[2, 3], vespers: <int>[18]);
      expect(kafizmy.label, "на утрени: 2, 3 · на вечерне: 18");

      expect(const OrdoKafizmy().label, isEmpty);
      expect(const OrdoKafizmy().isEmpty, isTrue);
      expect(kafizmy.isEmpty, isFalse);
    });

    test("все четыре службы в подписи", () {
      const kafizmy = OrdoKafizmy(
        matins: <int>[17],
        hours: <int>[17],
        vespers: <int>[1],
        midnight: <int>[18],
      );
      expect(kafizmy.label,
          "на утрени: 17 · на часах: 17 · на вечерне: 1 · на полунощнице: 18");
    });

    test("contains и servicesFor", () {
      const kafizmy = OrdoKafizmy(matins: <int>[2, 3], vespers: <int>[18]);
      expect(kafizmy.contains(2), isTrue);
      expect(kafizmy.contains(18), isTrue);
      expect(kafizmy.contains(5), isFalse);
      expect(kafizmy.servicesFor(2), <String>["на утрени"]);
      expect(kafizmy.servicesFor(3), <String>["на утрени"]);
      expect(kafizmy.servicesFor(18), <String>["на вечерне"]);
      expect(kafizmy.servicesFor(7), isEmpty);
    });

    test("мусор в списках пропускается", () {
      final kafizmy = OrdoKafizmy.fromJson(<String, dynamic>{
        "matins": <dynamic>[2, "3", null, -1, "мусор", 0],
      });
      expect(kafizmy.matins, <int>[2, 3]);
    });
  });

  group("OrdoDay", () {
    test("кафизмы есть", () {
      final day = OrdoDay.fromJson(<String, dynamic>{
        "date": "2026-10-14",
        "kafizmy": <String, dynamic>{
          "matins": <int>[2, 3],
          "vespers": <int>[18],
        },
      });
      expect(day.kafizmy, isNotNull);
      expect(day.kafizmy!.label, "на утрени: 2, 3 · на вечерне: 18");
    });

    test("кафизм нет — штатный null", () {
      expect(OrdoDay.fromJson(const <String, dynamic>{}).kafizmy, isNull);
      expect(
        OrdoDay.fromJson(const <String, dynamic>{"kafizmy": null}).kafizmy,
        isNull,
      );
      // Старый сервер: день есть, поля kafizmy он не знает.
      expect(
        OrdoDay.fromJson(const <String, dynamic>{"date": "2026-10-14"}).kafizmy,
        isNull,
      );
    });

    test("kafizmy не объект — null, а не падение", () {
      final day = OrdoDay.fromJson(const <String, dynamic>{
        "kafizmy": "2, 3",
      });
      expect(day.kafizmy, isNull);
    });
  });

  group("дата в параметре", () {
    test("ISO без времени, ноль дополнен", () {
      expect(ordoDayDate(DateTime(2026, 10, 14)), "2026-10-14");
      expect(ordoDayDate(DateTime(2026, 1, 5)), "2026-01-05");
      expect(ordoDayDate(DateTime(999, 12, 31)), "0999-12-31");
    });
  });
}
