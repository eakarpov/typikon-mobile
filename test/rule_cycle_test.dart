import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/pages/rule_page.dart';
import 'package:typikon/store/rule_cycle.dart';
import 'package:typikon/store/reading_progress.dart';
import 'package:typikon/utils/route_observer.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    '15:00 starts the evening and next morning; midnight preserves the cycle',
    () {
      final before = RuleCycle.at(DateTime(2026, 10, 26, 14, 59, 59));
      expect(before.key, '2026-10-25');
      expect(before.morning, DateTime(2026, 10, 26));
      expect(before.nextReset, DateTime(2026, 10, 26, 15));
      final after = RuleCycle.at(DateTime(2026, 10, 26, 15));
      expect(after.key, '2026-10-26');
      expect(after.morning, DateTime(2026, 10, 27));
      expect(after.nextReset, DateTime(2026, 10, 27, 15));
      expect(RuleCycle.at(DateTime(2026, 10, 27)).key, after.key);
      expect(RuleCycle.at(DateTime(2026, 11, 1, 1)).key, '2026-10-31');
      expect(RuleCycle.at(DateTime(2027, 1, 1, 1)).key, '2026-12-31');
    },
  );

  test(
    'migration combines previous evening with this morning exactly once',
    () async {
      SharedPreferences.setMockInitialValues({
        'rule_done:2026-10-25:evening_prayerbook': true,
        'rule_done:2026-10-25:morning_prayerbook': true,
        'rule_done:2026-10-26:morning_prayerbook': true,
        'rule_done:2026-10-26:compline': true,
      });
      final cycle = RuleCycle.at(DateTime(2026, 10, 26, 10));
      expect(await ruleCycleMarks(cycle), {
        'evening_prayerbook': true,
        'morning_prayerbook': true,
      });
      await setRuleCycleSectionDone(cycle, 'morning_prayerbook', false);
      expect((await ruleCycleMarks(cycle))['morning_prayerbook'], false);
      final next = RuleCycle.at(DateTime(2026, 10, 26, 15));
      expect(await ruleCycleMarks(next), {'compline': true});
    },
  );

  test(
    'continue reading hides finished cycles while retaining books',
    () async {
      final at = DateTime(2026, 10, 26, 14);
      final current = RuleCycle.at(at);
      await saveReadingProgress('rule:2026-10-25', .5);
      await saveReadingProgress('rule:cycle:2026-10-24', .5);
      await saveReadingProgress(current.progressId, .5);
      await saveReadingProgress('book', .5);
      expect(
        (await getAllReadingProgress(now: at)).map((e) => e.id),
        containsAll([current.progressId, 'book']),
      );
      expect(
        (await getAllReadingProgress(
          now: DateTime(2026, 10, 26, 15),
        )).map((e) => e.id),
        ['book'],
      );
    },
  );

  Future<void> showRule(WidgetTester tester, DateTime Function() clock) async {
    tester.view.physicalSize = const Size(1200, 10000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routeObserver],
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) =>
              Scaffold(appBar: AppBar(), body: const Text('Чтение')),
        ),
        home: RulePage(
          null,
          now: clock,
          loader: () async => const RuleDayData(),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'open screen resets at 15:00 and new progress can be marked and cleared',
    (tester) async {
      var now = DateTime(2026, 10, 26, 14, 59);
      final old = RuleCycle.at(now);
      await setRuleCycleSectionDone(old, 'evening_prayerbook', true);
      await setRuleCycleSectionDone(old, 'morning_prayerbook', true);
      await showRule(tester, () => now);
      expect(find.text('прочитано разделов: 2/2'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Вечер')).dy,
        lessThan(tester.getTopLeft(find.text('Утро')).dy),
      );
      now = DateTime(2026, 10, 26, 15);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.text('прочитано разделов: 0/2'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('прочитано разделов: 1/2'), findsOneWidget);
      expect(
        (await getReadingProgress(RuleCycle.at(now).progressId))?.fraction,
        .5,
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(await getReadingProgress(RuleCycle.at(now).progressId), null);
    },
  );

  testWidgets(
    'after midnight the same progress remains, after skipped reset it clears on resume',
    (tester) async {
      var now = DateTime(2026, 10, 26, 23, 59);
      await setRuleCycleSectionDone(
        RuleCycle.at(now),
        'evening_prayerbook',
        true,
      );
      await showRule(tester, () => now);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 10, 27, 7);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('прочитано разделов: 1/2'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 10, 29, 16);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('прочитано разделов: 0/2'), findsOneWidget);
    },
  );

  testWidgets(
    'return from a reading rechecks cycle even if device clock jumps',
    (tester) async {
      var now = DateTime(2026, 10, 26, 14);
      await setRuleCycleSectionDone(
        RuleCycle.at(now),
        'evening_prayerbook',
        true,
      );
      await showRule(tester, () => now);
      await tester.tap(find.text('Молитвы на сон грядущим'));
      await tester.pumpAndSettle();
      now = DateTime(2026, 10, 26, 16);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('прочитано разделов: 0/2'), findsOneWidget);
    },
  );
}
