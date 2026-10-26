import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/dto/corpus.dart';
import 'package:typikon/pages/rule_page.dart';
import 'package:typikon/pages/rule_office_page.dart';
import 'package:typikon/pages/posledovanie_page.dart';

FacetedPage<Canon, CanonFacets> page(
  List<Canon> items, {
  int total = 1,
  int offset = 0,
}) => FacetedPage(
  items: items,
  total: total,
  limit: 25,
  offset: offset,
  facets: const CanonFacets(),
);
const midnight = Canon(
  id: 'midnight-3',
  memory: 'Троице',
  service: 'midnight',
  book: 'octoechos',
  weekday: 'voskresenie',
  memoryTone: 3,
  tone: 6,
  language: 'cu_gr',
);
const compline = Canon(
  id: 'compline-3',
  memory: 'Богородице',
  service: 'compline',
  book: 'octoechos',
  weekday: 'voskresenie',
  memoryTone: 3,
  tone: 3,
  language: 'cu_gr',
);

void main() {
  test('Молитвослов не подбирает каноны утрени или повечерия', () async {
    var calls = 0;
    final result = await loadRuleDay(
      now: DateTime(2026, 10, 25),
      canons: ({query, offset = 0, book, tone, service, role}) async {
        calls++;
        return page([]);
      },
      toneLoader: (_) async {
        calls++;
        return 3;
      },
      dayLoader: (_) async => throw Exception('offline'),
    );
    expect(calls, 0);
    expect(result.morningCanon, isNull);
    expect(result.eveningCanon, isNull);
  });
  test('полунощница по дню недели; канон только в воскресенье', () async {
    expect(midnightTextId(DateTime.monday), midnightDailyTextId);
    expect(midnightTextId(DateTime.saturday), midnightSaturdayTextId);
    expect(midnightTextId(DateTime.sunday), midnightSundayTextId);
    var calls = 0;
    for (final date in [DateTime(2026, 10, 24), DateTime(2026, 10, 26)]) {
      final result = await loadRuleDay(
        now: date,
        morningOffice: true,
        canons: ({query, offset = 0, book, tone, service, role}) async {
          calls++;
          return page([]);
        },
        toneLoader: (_) async => 3,
        dayLoader: (_) async => throw Exception('offline'),
      );
      expect(result.morningCanon, isNull);
    }
    expect(calls, 0);
  });
  test(
    'воскресный канон выбирается из midnight по гласу памяти, не из matins',
    () async {
      final services = <String?>[];
      final result = await loadRuleDay(
        now: DateTime(2026, 10, 25),
        morningOffice: true,
        eveningOffice: true,
        toneLoader: (_) async => 3,
        dayLoader: (_) async => throw Exception('offline'),
        canons: ({query, offset = 0, book, tone, service, role}) async {
          services.add(service);
          expect(book, 'octoechos');
          expect(tone, isNull);
          return page(service == 'midnight' ? [midnight] : [compline]);
        },
      );
      expect(services, ['midnight', 'compline']);
      expect(result.morningCanon?.id, midnight.id);
      expect(result.eveningCanon?.id, compline.id);
    },
  );
  test(
    'не берёт первый случайный канон, умеет пройти следующую страницу',
    () async {
      final result = await loadRuleDay(
        now: DateTime(2026, 10, 25),
        morningOffice: true,
        toneLoader: (_) async => 3,
        dayLoader: (_) async => throw Exception('offline'),
        canons: ({query, offset = 0, book, tone, service, role}) async =>
            offset == 0
            ? page([
                const Canon(
                  id: 'wrong',
                  memory: '',
                  weekday: 'voskresenie',
                  memoryTone: 1,
                ),
              ], total: 26)
            : page([midnight], total: 26, offset: 25),
      );
      expect(result.morningCanon?.id, midnight.id);
    },
  );

  test(
    'цикл подбирает субботнее повечерие и воскресную полунощницу по разным датам и гласам',
    () async {
      const saturday = Canon(
        id: 'saturday',
        memory: 'Богородице',
        service: 'compline',
        book: 'octoechos',
        weekday: 'subbota',
        memoryTone: 2,
        language: 'cu',
      );
      final dates = <DateTime>[];
      String? gospelDate;
      final result = await loadRuleDay(
        now: DateTime(2026, 10, 25),
        eveningDate: DateTime(2026, 10, 24),
        morningOffice: true,
        eveningOffice: true,
        toneLoader: (date) async {
          dates.add(date);
          return date.day == 24 ? 2 : 3;
        },
        canons: ({query, offset = 0, book, tone, service, role}) async =>
            page(service == 'midnight' ? [midnight] : [saturday]),
        dayLoader: (date) async {
          gospelDate = date;
          throw StateError('no gospel');
        },
      );
      expect(result.morningCanon?.id, midnight.id);
      expect(result.eveningCanon?.id, saturday.id);
      expect(result.tone, 3);
      expect(result.eveningTone, 2);
      expect(dates, [DateTime(2026, 10, 25), DateTime(2026, 10, 24)]);
      expect(gospelDate, '2026-10-25');
    },
  );

  test(
    'отказ гласа вечернего дня не подменяется гласом следующего утра',
    () async {
      final result = await loadRuleDay(
        now: DateTime(2026, 10, 25),
        eveningDate: DateTime(2026, 10, 24),
        morningOffice: true,
        eveningOffice: true,
        toneLoader: (date) async => date.day == 24 ? null : 3,
        canons: ({query, offset = 0, book, tone, service, role}) async =>
            page([midnight]),
        dayLoader: (_) async => throw StateError('no gospel'),
      );
      expect(result.morningCanon?.id, midnight.id);
      expect(result.eveningCanon, isNull);
      expect(result.eveningTone, isNull);
    },
  );

  Future<void> pump(
    WidgetTester tester, {
    DateTime? date,
    Map<String, Object> prefs = const {},
    void Function(RouteSettings)? onPush,
  }) async {
    tester.view.physicalSize = const Size(1200, 10000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: onPush == null
            ? null
            : (settings) {
                onPush(settings);
                return MaterialPageRoute(
                  builder: (_) =>
                      Scaffold(appBar: AppBar(), body: const Text('Открыто')),
                );
              },
        home: RulePage(
          null,
          date: date ?? DateTime(2026, 10, 25),
          loader: () async => const RuleDayData(
            morningCanon: midnight,
            eveningCanon: compline,
            tone: 3,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'по умолчанию обе молитвы — из Молитвослова, без отдельного канона',
    (tester) async {
      final routes = <RouteSettings>[];
      await pump(tester, onPush: routes.add);
      expect(find.text('Полунощница воскресная'), findsNothing);
      expect(find.text('Канон утренний'), findsNothing);
      await tester.tap(find.text('Молитвы утренние'));
      await tester.pumpAndSettle();
      expect(routes.single.name, '/posledovanie');
      expect(
        parsePosledovanieArgument(routes.single.arguments as String)?.key,
        'utrennie',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Молитвы на сон грядущим'));
      await tester.pumpAndSettle();
      expect(
        parsePosledovanieArgument(routes.last.arguments as String)?.key,
        'na-son',
      );
    },
  );
  testWidgets(
    'сохранённый Часослов открывает воскресную полунощницу и повечерие с каноном',
    (tester) async {
      final routes = <RouteSettings>[];
      await pump(
        tester,
        prefs: {
          'rule_morning_horologion': true,
          'rule_evening_horologion': true,
        },
        onPush: routes.add,
      );
      expect(find.text('Утренние молитвы Часослова'), findsOneWidget);
      await tester.tap(find.text('Полунощница воскресная'));
      await tester.pumpAndSettle();
      final target = routes.single.arguments as RuleOfficeTarget;
      expect(target.textId, midnightSundayTextId);
      expect(target.canonId, midnight.id);
      expect(target.tone, 3);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Повечерие с каноном'));
      await tester.pumpAndSettle();
      expect((routes.last.arguments as RuleOfficeTarget).canonId, compline.id);
    },
  );
  testWidgets(
    'выбор варианта сохраняется; отметки другого варианта не засчитываются',
    (tester) async {
      await pump(
        tester,
        prefs: {'rule_done:2026-10-25:morning_prayerbook': true},
      );
      final choice = tester.widget<SegmentedButton<bool>>(
        find.byKey(const ValueKey('morning_source')),
      );
      choice.onSelectionChanged!({true});
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'rule_morning_horologion',
        ),
        true,
      );
      expect(find.text('прочитано разделов: 0/3'), findsOneWidget);
      expect(find.text('Полунощница воскресная'), findsOneWidget);
    },
  );
}
