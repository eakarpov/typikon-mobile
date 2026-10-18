import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/domain/psalter.dart';
import 'package:typikon/dto/ordo.dart';
import 'package:typikon/pages/psalter_page.dart';
import 'package:typikon/store/psalter_mode.dart';

// Список Псалтири: двадцать кафизм, дополнительный Пс 151, вход в «Подряд».
// Кафизма показывает прогресс по статьям и пометку «сегодня» по уставу.

Future<void> pumpPsalter(
  WidgetTester tester, {
  required Future<OrdoKafizmy?> Function() todayLoader,
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  // Весь список (24 пункта) должен поместиться на экран, чтобы находился
  // без листания.
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  await tester.pumpWidget(MaterialApp(
    home: PsalterPage(todayLoader: todayLoader),
  ));
  await tester.pumpAndSettle();
}

Map<String, Object> progressPrefs(Map<String, double> fractions) {
  final entries = <String, dynamic>{};
  fractions.forEach((id, fraction) {
    entries[id] = <String, dynamic>{
      "fraction": fraction,
      "updatedAt": DateTime(2026, 1, 1).millisecondsSinceEpoch,
    };
  });
  return <String, Object>{"reading_progress": jsonEncode(entries)};
}

void main() {
  testWidgets("список: двадцать кафизм, Пс 151 и «Подряд»", (tester) async {
    await pumpPsalter(tester, todayLoader: () async => null);

    expect(find.text("Псалтирь"), findsOneWidget);
    for (final number in kathismaRanges.keys) {
      expect(find.text(kathismaTitle(number)), findsOneWidget,
          reason: "в списке нет ${kathismaTitle(number)}");
    }
    expect(find.text("Псалом 151 (дополнительный)"), findsOneWidget);
    expect(find.text("Подряд"), findsOneWidget);

    // Без ответа ordo пометок «сегодня» нет вовсе.
    expect(find.text("Сегодня по уставу"), findsNothing);
    expect(find.text("Сегодня"), findsNothing);
  });

  testWidgets("прогресс по статьям из доли скролла", (tester) async {
    await pumpPsalter(
      tester,
      todayLoader: () async => null,
      prefs: progressPrefs(<String, double>{
        "psalter:kathisma:2": 0.5, // 0.5 × 3 = 1.5 → 2 статьи
        "psalter:kathisma:11": 0.1, // 0.1 × 3 ≈ 0.3 → 0 статей, не показываем
      }),
    );

    expect(find.text("прочитано статей: 2/3"), findsOneWidget);

    final bars = tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(bars.map((bar) => bar.value), <double>[2 / 3]);
  });

  testWidgets("«сегодня» по уставу: подпись дня и метки кафизм", (tester) async {
    await pumpPsalter(
      tester,
      todayLoader: () async => const OrdoKafizmy(
        matins: <int>[2, 3],
        vespers: <int>[18],
      ),
    );

    expect(find.text("Сегодня по уставу"), findsOneWidget);
    expect(find.text("на утрени: 2, 3 · на вечерне: 18"), findsOneWidget);

    // Метки у кафизм 2, 3 и 18 — и ни у одной больше.
    expect(find.text("Сегодня"), findsNWidgets(3));
    expect(find.text("сегодня: на утрени"), findsNWidgets(2));
    expect(find.text("сегодня: на вечерне"), findsOneWidget);
  });

  testWidgets("тап в кафизму ведёт на /psalter/kathisma с её номером",
      (tester) async {
    final pushed = <String>[];
    Object? kathismaArgs;
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (settings) {
        pushed.add(settings.name ?? "");
        if (settings.name == "/psalter/kathisma") {
          kathismaArgs = settings.arguments;
        }
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text("открыто")),
        );
      },
      home: PsalterPage(todayLoader: () async => null),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text("6-я кафизма"));
    await tester.pumpAndSettle();

    expect(pushed, contains("/psalter/kathisma"));
    expect(kathismaArgs, 6);
  });

  testWidgets("тап в «Подряд» ведёт на /psalter/serial без аргумента",
      (tester) async {
    final pushed = <String>[];
    Object? serialArgs = "не-тронут";
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (settings) {
        pushed.add(settings.name ?? "");
        if (settings.name == "/psalter/serial") {
          serialArgs = settings.arguments;
        }
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text("открыто")),
        );
      },
      home: PsalterPage(todayLoader: () async => null),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Подряд"));
    await tester.pumpAndSettle();

    expect(pushed, contains("/psalter/serial"));
    expect(serialArgs, isNull);
  });

  group("раздел «О усопших»", () {
    Future<CapturedNav> pumpForNav(
      WidgetTester tester, {
      Map<String, Object> prefs = const <String, Object>{},
    }) async {
      final nav = CapturedNav();
      tester.view.physicalSize = const Size(1200, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(prefs);
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (settings) {
          nav.pushed.add(settings.name ?? "");
          nav.arguments.add(settings.arguments);
          // Фальшивая страница со стрелкой «назад»: возвращаемся домой
          // между переходами.
          return MaterialPageRoute(
            builder: (_) => Scaffold(appBar: AppBar(), body: const Text("открыто")),
          );
        },
        home: PsalterPage(todayLoader: () async => null),
      ));
      await tester.pumpAndSettle();
      return nav;
    }

    Future<void> goBack(WidgetTester tester) async {
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }

    testWidgets("три входа на месте", (tester) async {
      await pumpForNav(tester);

      expect(find.text("О усопших"), findsOneWidget);
      expect(find.text("Чтение с поминовением"), findsOneWidget);
      expect(find.text("имена усопших на славах"), findsOneWidget);
      expect(find.text("Сорокоуст"), findsOneWidget);
      expect(find.text("Неусыпаемая Псалтирь"), findsOneWidget);
      // Режим по умолчанию выключен.
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets("режим выключен: прежние аргументы — int и null",
        (tester) async {
      final nav = await pumpForNav(tester);

      await tester.tap(find.text("6-я кафизма"));
      await tester.pumpAndSettle();
      expect(nav.arguments.last, 6);
      await goBack(tester);

      await tester.tap(find.text("Подряд"));
      await tester.pumpAndSettle();
      expect(nav.arguments.last, isNull);
    });

    testWidgets("переключатель пишет ключ и меняет аргументы на «N|d» и «d»",
        (tester) async {
      final nav = await pumpForNav(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(await psalterDepartedMode(), isTrue);

      await tester.tap(find.text("6-я кафизма"));
      await tester.pumpAndSettle();
      expect(nav.arguments.last, "6|d");
      await goBack(tester);

      await tester.tap(find.text("Подряд"));
      await tester.pumpAndSettle();
      expect(nav.arguments.last, "d");
    });

    testWidgets("режим восстанавливается из ключа", (tester) async {
      await pumpForNav(
        tester,
        prefs: const <String, Object>{"psalter_departed_mode": true},
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);
    });

    testWidgets("«Сорокоуст» ведёт на /psalter/sorokoust, «Неусыпаемая» — на "
        "serial с флагом «d»", (tester) async {
      final nav = await pumpForNav(tester);

      await tester.tap(find.text("Сорокоуст"));
      await tester.pumpAndSettle();
      expect(nav.pushed.last, "/psalter/sorokoust");
      await goBack(tester);

      await tester.tap(find.text("Неусыпаемая Псалтирь"));
      await tester.pumpAndSettle();
      expect(nav.pushed.last, "/psalter/serial");
      expect(nav.arguments.last, "d");
    });
  });
}

class CapturedNav {
  final pushed = <String>[];
  final arguments = <Object?>[];
}
