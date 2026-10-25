import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/store/communion_plan.dart';
import 'package:typikon/utils/communion_reminders.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final plan = CommunionPlan(DateTime(2026, 10, 21), DateTime(2026, 10, 25));

  test('не угадывает дату; нужны план, согласие и вечернее окно', () {
    bool shows({CommunionPlan? chosen, bool enabled = true, DateTime? at}) =>
        communionReminderVerdict(
          plan: chosen,
          enabled: enabled,
          lastNotifiedDate: null,
          now: at ?? DateTime(2026, 10, 22, 21),
        ).shows;
    expect(shows(), isFalse);
    expect(shows(chosen: plan, enabled: false), isFalse);
    expect(shows(chosen: plan, at: DateTime(2026, 10, 21, 21)), isFalse);
    expect(shows(chosen: plan, at: DateTime(2026, 10, 22, 20, 59)), isFalse);
    expect(shows(chosen: plan, at: DateTime(2026, 10, 22, 21)), isTrue);
    expect(shows(chosen: plan, at: DateTime(2026, 10, 22, 23)), isFalse);
    expect(shows(chosen: plan, at: DateTime(2026, 10, 25, 21)), isFalse);
    expect(shows(chosen: plan, at: DateTime(2026, 10, 26, 21)), isFalse);
  });

  test('напоминает один раз, ведёт к выбранной дате', () async {
    await saveCommunionPlan(plan);
    await setCommunionReminder(true);
    final sent = <String>[];
    Future<void> show(String body, String payload) async {
      sent.add(payload);
    }

    await checkCommunionRemindersAndNotify(
      show: show,
      now: DateTime(2026, 10, 22, 21),
    );
    await checkCommunionRemindersAndNotify(
      show: show,
      now: DateTime(2026, 10, 22, 22),
    );
    expect(sent, ['communion:2026-10-25']);
  });

  test('прочитанный вечер молчит; неудачный показ можно повторить', () async {
    await saveCommunionPlan(plan);
    await setCommunionReminder(true);
    final prefs = await SharedPreferences.getInstance();
    for (final id in communionPreparationItemIds) {
      await prefs.setBool('communion_done:2026-10-25:$id', true);
    }
    var sent = 0;
    await checkCommunionRemindersAndNotify(
      show: (_, _) async {
        sent++;
      },
      now: DateTime(2026, 10, 22, 21),
    );
    expect(sent, 0);
    await prefs.setBool('communion_done:2026-10-25:prayers', false);
    await expectLater(
      checkCommunionRemindersAndNotify(
        show: (_, _) async => throw Exception('не показано'),
        now: DateTime(2026, 10, 23, 21),
      ),
      throwsException,
    );
    expect(prefs.getString(communionLastNoticeKey), isNull);
  });

  test(
    'выбор нового плана сохраняет даты и выключает прежние напоминания',
    () async {
      await saveCommunionPlan(plan);
      await setCommunionReminder(true);
      final restored = await getCommunionPlan();
      expect(restored?.start, plan.start);
      expect(restored?.date, plan.date);
      await saveCommunionPlan(
        CommunionPlan(plan.start, DateTime(2026, 10, 26)),
      );
      expect(await communionReminderEnabled(), isFalse);
      expect(parseCommunionDate('2026-02-31'), isNull);
    },
  );
}
