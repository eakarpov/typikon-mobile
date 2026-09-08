import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/pomyannik.dart';
import 'package:typikon/store/pomyannik_cache.dart';
import 'package:typikon/utils/pomyannik_reminders.dart';

// Ворота напоминания. Ошибка в любом из них видна не в отладке, а в жизни: одна
// будит человека в три ночи, другая повторяет одно и то же четырежды за утро,
// третья напоминает о том, кого он уже убрал из помянника.
//
// Отдельно стоит то, чего мы НЕ делаем: не доигрываем вчерашнее. «Вчера был
// сороковой день» — это напоминание, которое уже не сработало, и поданное поздно
// оно только обнадёживает зря.

PomyannikMirror mirror({
  DateTime? fetchedAt,
  List<UpcomingEvent> events = const [],
  String userId = "user-1",
}) =>
    PomyannikMirror(
      userId: userId,
      fetchedAt: fetchedAt ?? DateTime(2026, 9, 8, 9),
      from: "2026-09-08",
      days: 60,
      events: events,
    );

UpcomingEvent event(String date, {String title = "Сороковой день: Николай", String? personId}) =>
    UpcomingEvent(date: date, kind: "fortieth", title: title, personId: personId);

ReminderVerdict verdict({
  bool enabled = true,
  PomyannikMirror? on,
  String? lastNotified,
  DateTime? now,
  bool withNames = false,
}) =>
    pomyannikVerdict(
      enabled: enabled,
      mirror: on ?? mirror(events: [event("2026-09-08")]),
      lastNotifiedDate: lastNotified,
      now: now ?? DateTime(2026, 9, 8, 9),
      withNames: withNames,
    );

void main() {
  group("когда молчим", () {
    test("пока не включили — молчим", () {
      // Заводить уведомления об умерших родственниках всякому, кто вошёл в
      // учётную запись, нельзя.
      expect(verdict(enabled: false).shows, isFalse);
    });

    test("до восьми утра — молчим", () {
      // Окно даёт система, а показываем мы: задача просыпается когда угодно.
      expect(verdict(now: DateTime(2026, 9, 8, 3)).shows, isFalse);
      expect(verdict(now: DateTime(2026, 9, 8, 7, 59)).shows, isFalse);
      expect(verdict(now: DateTime(2026, 9, 8, 8)).shows, isTrue);
    });

    test("после девяти вечера — молчим", () {
      expect(verdict(now: DateTime(2026, 9, 8, 20, 59)).shows, isTrue);
      expect(verdict(now: DateTime(2026, 9, 8, 21)).shows, isFalse);
      expect(verdict(now: DateTime(2026, 9, 8, 23, 30)).shows, isFalse);
    });

    test("дважды в день не говорим", () {
      expect(verdict(lastNotified: "2026-09-08").shows, isFalse);
      expect(verdict(lastNotified: "2026-09-07").shows, isTrue);
    });

    test("зеркала нет — молчим", () {
      expect(pomyannikVerdict(
        enabled: true,
        mirror: null,
        lastNotifiedDate: null,
        now: DateTime(2026, 9, 8, 9),
        withNames: false,
      ).shows, isFalse);
    });

    test("зеркалу больше двух недель — молчим", () {
      // За это время хозяин мог убрать имя в вебе, и напоминание о нём хуже
      // молчания.
      expect(
        verdict(
          on: mirror(fetchedAt: DateTime(2026, 8, 24, 9), events: [event("2026-09-08")]),
        ).shows,
        isFalse,
      );
      expect(
        verdict(
          on: mirror(fetchedAt: DateTime(2026, 8, 26, 9), events: [event("2026-09-08")]),
        ).shows,
        isTrue,
      );
    });

    test("сегодня нечего сказать — молчим", () {
      expect(verdict(on: mirror(events: [event("2026-09-20")])).shows, isFalse);
    });

    test("вчерашнее не доигрываем", () {
      // Напоминание, поданное на день позже, не напоминание, а обманутая надежда.
      expect(verdict(on: mirror(events: [event("2026-09-07")])).shows, isFalse);
    });
  });

  group("что говорим", () {
    test("без имён — только о том, что день есть", () {
      // Уведомление висит на экране блокировки, и по умолчанию имени там не место.
      final said = verdict();

      expect(said.body, "Сегодня поминальный день");
      expect(said.payload, "pomyannik:upcoming");
    });

    test("несколько дней сразу — числом, а не перечнем", () {
      final said = verdict(
        on: mirror(events: [event("2026-09-08"), event("2026-09-08")]),
      );

      expect(said.body, "Сегодня поминальных дней: 2");
    });

    test("с именами — так, как их составил сервер", () {
      final said = verdict(
        withNames: true,
        on: mirror(events: [event("2026-09-08", personId: "p1")]),
      );

      expect(said.body, "Сороковой день: Николай");
      expect(said.payload, "pomyannik:p1", reason: "ведёт на того, о ком речь");
    });

    test("имена включены, а в зеркале их нет — говорим без имён", () {
      // Зеркало пишется по настройке на минуту записи: включили имена, но
      // зеркало ещё старое — заголовков в нём нет, и выдумывать их нечем.
      final said = verdict(
        withNames: true,
        on: mirror(events: [event("2026-09-08", title: "")]),
      );

      expect(said.body, "Сегодня поминальный день");
    });
  });

  group("зеркало", () {
    test("имена на диск не ложатся, пока их не разрешили", () async {
      // Проверяем сам отбор, без файла: диск здесь не при чём, а правило — да.
      final kept = UpcomingEvent(
        date: "2026-09-08", kind: "fortieth", title: "Сороковой день: Николай",
        personId: "p1", custom: false,
      );

      expect(kept.toJson()["title"], "Сороковой день: Николай");
      expect(
        UpcomingEvent(date: kept.date, kind: kept.kind, title: "", personId: kept.personId)
            .toJson()["title"],
        "",
      );
    });

    test("чужое зеркало своим не считается", () {
      // На одном устройстве входят и выходят разные люди — то же правило, что у
      // избранного.
      final mine = mirror(userId: "user-1");

      expect(mirrorBelongsTo(mine, "user-1"), isTrue);
      expect(mirrorBelongsTo(mine, "user-2"), isFalse);
      expect(mirrorBelongsTo(mine, null), isFalse);
      expect(mirrorBelongsTo(null, "user-1"), isFalse);
    });

    test("испорченное зеркало читается как отсутствующее", () {
      expect(PomyannikMirror.fromJson({"userId": "", "fetchedAt": "2026-09-08"}), isNull);
      expect(PomyannikMirror.fromJson({"userId": "u", "fetchedAt": "мусор"}), isNull);
      expect(PomyannikMirror.fromJson({"userId": "u", "fetchedAt": "2026-09-08T09:00:00.000"}),
          isNotNull);
    });
  });
}
