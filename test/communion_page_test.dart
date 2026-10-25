import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/pages/communion_page.dart';
import 'package:typikon/pages/posledovanie_page.dart';
import 'package:typikon/dto/posledovanie.dart';

Future<void> pumpCommunion(
  WidgetTester tester, {
  required DateTime today,
  DateTime? initialDate,
  Map<String, Object> prefs = const {},
  void Function(String, Object?)? onPush,
}) async {
  tester.view.physicalSize = const Size(1200, 10000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ru'), Locale('en')],
      onGenerateRoute: onPush == null
          ? null
          : (settings) {
              onPush(settings.name!, settings.arguments);
              return MaterialPageRoute(
                builder: (_) =>
                    Scaffold(appBar: AppBar(), body: const Text('открыто')),
              );
            },
      home: CommunionPage(
        null,
        today: today,
        initialDate: initialDate,
        trapeza: (_) => const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final today = DateTime(2026, 10, 14);
  testWidgets('сначала нужен явный выбор даты', (tester) async {
    await pumpCommunion(tester, today: today);
    expect(find.text('Выбрать день причащения'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.text('Выбрать день причащения'));
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 10, 20));
    await tester.pump();
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('communion_plan_date'), '2026-10-20');
    expect(prefs.getString('communion_plan_start'), '2026-10-17');
    expect(prefs.getBool('communion_remind'), false);
  });
  for (final gap in [0, 3, 15, 40]) {
    testWidgets(
      'через $gap дней: только три канона, последование, молитвы и благодарственные',
      (tester) async {
        final date = today.add(Duration(days: gap));
        await pumpCommunion(tester, today: today, initialDate: date);
        for (final title in [
          'Канон покаянный',
          'Канон Богородице',
          'Канон Ангелу хранителю',
          'Последование ко Причащению',
          'Молитвы ко Причащению',
          'Благодарственные молитвы',
        ]) {
          expect(find.text(title), findsOneWidget);
        }
        expect(find.byType(Checkbox), findsNWidgets(6));
        expect(find.textContaining('Пост ·'), findsNWidgets(3));
        expect(find.textContaining('вечером'), findsNothing);
      },
    );
  }
  testWidgets(
    'чтения ведут к канонам и к непересекающимся частям последования',
    (tester) async {
      final routes = <(String, Object?)>[];
      await pumpCommunion(
        tester,
        today: today,
        initialDate: DateTime(2026, 10, 17),
        onPush: (route, args) => routes.add((route, args)),
      );
      for (final title in [
        'Канон покаянный',
        'Канон Богородице',
        'Канон Ангелу хранителю',
        'Последование ко Причащению',
        'Молитвы ко Причащению',
        'Благодарственные молитвы',
      ]) {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(routes.take(3).map((r) => r.$2), communionCanons.map((c) => c.$1));
      expect(
        parsePosledovanieArgument(routes[3].$2 as String)?.part,
        PosledovaniePart.beforeCommunion,
      );
      expect(
        parsePosledovanieArgument(routes[4].$2 as String)?.part,
        PosledovaniePart.communionPrayers,
      );
    },
  );
  test('граница молитв работает для уставного и гражданского слоёв', () {
    for (final label in [
      'Моли́тва 1-я, свт. Васи́лия',
      'Мл҃тва а҃, ст҃а́гѡ васі́лїа',
    ]) {
      final rows = [
        const PosledovanieRow(text: 'Последование'),
        PosledovanieRow(label: label, text: 'Первая молитва'),
        const PosledovanieRow(text: 'Вторая молитва'),
      ];
      expect(
        communionRows(
          rows,
          PosledovaniePart.beforeCommunion,
        ).map((r) => r.text),
        ['Последование'],
      );
      expect(
        communionRows(
          rows,
          PosledovaniePart.communionPrayers,
        ).map((r) => r.text),
        ['Первая молитва', 'Вторая молитва'],
      );
    }
    expect(
      () => communionRows([], PosledovaniePart.beforeCommunion),
      throwsFormatException,
    );
  });
  testWidgets('старые отметки мигрируют, новый список хранится один раз', (
    tester,
  ) async {
    await pumpCommunion(
      tester,
      today: today,
      initialDate: DateTime(2026, 10, 17),
      prefs: {
        'communion_done:2026-10-17:evening0:canon': true,
        'communion_done:2026-10-17:evening1:posledovanie': true,
      },
    );
    expect(find.text('прочитано: 3/6'), findsOneWidget);
    final boxes = find.byType(Checkbox);
    for (var i = 0; i < 6; i++) {
      if (tester.widget<Checkbox>(boxes.at(i)).value != true) {
        await tester.tap(boxes.at(i));
        await tester.pumpAndSettle();
      }
    }
    expect(find.text('прочитано: 6/6'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(prefs.getString('reading_progress') ?? '{}') as Map;
    expect(saved.containsKey('communion:2026-10-17'), false);
    await tester.tap(boxes.first);
    await tester.pumpAndSettle();
    expect(prefs.getBool('communion_done:2026-10-17:canon:0'), false);
  });
  testWidgets('старое уведомление не меняет действующий план', (tester) async {
    await pumpCommunion(
      tester,
      today: today,
      initialDate: DateTime(2026, 10, 15),
      prefs: {
        'communion_plan_start': '2026-10-14',
        'communion_plan_date': '2026-10-18',
        'communion_remind': true,
      },
    );
    expect(find.text('18 октября 2026'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      true,
    );
    await tester.tap(find.text('День причащения'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getBool('communion_remind'),
      true,
    );
  });
}
