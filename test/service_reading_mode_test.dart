import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:typikon/components/highlighted_text.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/components/service_mode_theme.dart';
import 'package:typikon/components/service_reading_scope.dart';
import 'package:typikon/utils/service_mode.dart';
import 'package:typikon/utils/service_night_palette.dart';
import 'package:typikon/utils/reading_style.dart';
import 'package:typikon/utils/route_observer.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'ночная палитра и листание сохраняются независимо от включения режима',
    () async {
      final mode = ServiceModeController(apply: (_) async {});
      await mode.load();
      await mode.setNightPalette(false);
      await mode.setEdgePaging(false);
      await mode.setEnabled(true);
      final restored = ServiceModeController(apply: (_) async {});
      await restored.load();
      expect(restored.value, true);
      expect(restored.nightPalette, false);
      expect(restored.edgePaging, false);
      mode.dispose();
      restored.dispose();
    },
  );

  testWidgets(
    'ночь перекрывает пользовательские цвета только в активном читателе',
    (tester) async {
      final mode = ServiceModeController(apply: (_) async {});
      final initial = AppState.init();
      final state = AppState(
        common: initial.common,
        settings: initial.settings.copyWith(
          fontColor: Colors.blue,
          backgroundColor: Colors.white,
        ),
      );
      final store = Store<AppState>(appReducer, initialState: state);
      final navigator = GlobalKey<NavigatorState>();
      Color? foreground, background;
      Brightness? brightness;
      await tester.pumpWidget(
        StoreProvider<AppState>(
          store: store,
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [routeObserver],
            theme: ThemeData.light(),
            builder: (context, child) =>
                ServiceModeTheme(controller: mode, child: child!),
            home: Scaffold(
              appBar: AppBar(title: const Text('Чтение')),
              body: ServiceReadingScope(
                controller: mode,
                child: Builder(
                  builder: (context) {
                    foreground = readingTextColor(context);
                    background = readingBackgroundColor(context);
                    brightness = Theme.of(context).brightness;
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(foreground, Colors.blue);
      expect(background, Colors.white);
      await mode.setEnabled(true);
      await tester.pumpAndSettle();
      expect(foreground, ServiceNightPalette.foreground);
      expect(background, Colors.black);
      expect(brightness, Brightness.dark);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            body: Builder(
              builder: (context) {
                return Text(
                  '${Theme.of(context).brightness}',
                  key: const Key('menu'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('menu'))).data,
        'Brightness.light',
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await mode.setNightPalette(false);
      await tester.pumpAndSettle();
      expect(foreground, Colors.blue);
      expect(background, Colors.white);
      expect(mode.value, true);
      expect(store.state.settings.fontColor, Colors.blue);
      await tester.pumpWidget(const SizedBox.shrink());
      await mode.settled;
      mode.dispose();
    },
  );

  for (final useList in [true, false]) {
    testWidgets(
      'листает ${useList ? 'список' : 'обычный текст'} без предварительного свайпа',
      (tester) async {
        final mode = ServiceModeController(apply: (_) async {});
        final scroll = ScrollController();
        final body = useList
            ? ListView(
                controller: scroll,
                children: const [SizedBox(height: 4000)],
              )
            : SingleChildScrollView(
                controller: scroll,
                child: const SizedBox(height: 4000, width: double.infinity),
              );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ServiceReadingScope(controller: mode, child: body),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await mode.setEnabled(true);
        await tester.pumpAndSettle();
        final viewport = scroll.position.viewportDimension;
        await tester.tapAt(const Offset(790, 250));
        await tester.pumpAndSettle();
        expect(scroll.offset, closeTo(viewport * .85, 1));
        await tester.tapAt(const Offset(10, 250));
        await tester.pumpAndSettle();
        expect(scroll.offset, 0);
        await tester.tap(find.byTooltip('Следующий экран'));
        await tester.pumpAndSettle();
        expect(scroll.offset, closeTo(viewport * .85, 1));
        await mode.setEdgePaging(false);
        await tester.pumpAndSettle();
        final before = scroll.offset;
        await tester.tapAt(const Offset(790, 250));
        await tester.pumpAndSettle();
        expect(scroll.offset, before);
        await tester.pumpWidget(const SizedBox.shrink());
        await mode.settled;
        mode.dispose();
        scroll.dispose();
      },
    );
  }

  test('подсветка поиска ночью использует тёмную красную подложку', () {
    final spans = buildHighlightedSpans(
      'Молитва',
      const TextStyle(color: ServiceNightPalette.foreground),
      [],
      (_) {},
      searchMatches: [(0, 7)],
      activeMatch: (0, 7),
      nightPalette: true,
    );
    expect(
      (spans.first as TextSpan).style?.backgroundColor,
      const Color(0xFF62251D),
    );
  });

  testWidgets('ссылка у края открывается без перелистывания', (tester) async {
    final mode = ServiceModeController(apply: (_) async {});
    final scroll = ScrollController();
    var clicks = 0;
    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        clicks++;
      };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceReadingScope(
            controller: mode,
            child: ListView(
              controller: scroll,
              children: [
                const SizedBox(height: 180),
                Align(
                  alignment: Alignment.centerRight,
                  child: RichText(
                    text: TextSpan(
                      text: 'Ссылка',
                      style: const TextStyle(color: Colors.black),
                      recognizer: recognizer,
                    ),
                  ),
                ),
                const SizedBox(height: 4000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await mode.setEnabled(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ссылка', findRichText: true));
    await tester.pumpAndSettle();
    expect(clicks, 1);
    expect(scroll.offset, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await mode.settled;
    mode.dispose();
    scroll.dispose();
    recognizer.dispose();
  });

  testWidgets('долгое нажатие, два пальца, центр и кнопки не листают', (
    tester,
  ) async {
    final mode = ServiceModeController(apply: (_) async {});
    final scroll = ScrollController();
    var clicks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceReadingScope(
            controller: mode,
            child: ListView(
              controller: scroll,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      clicks++;
                    },
                    child: const Text('Ссылка'),
                  ),
                ),
                const SizedBox(height: 4000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await mode.setEnabled(true);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 250));
    await tester.longPressAt(const Offset(790, 250));
    final a = await tester.startGesture(const Offset(790, 250), pointer: 1);
    final b = await tester.startGesture(const Offset(770, 250), pointer: 2);
    await a.up();
    await b.up();
    await tester.tap(find.text('Ссылка'));
    await tester.pumpAndSettle();
    expect(clicks, 1);
    expect(scroll.offset, 0);
    // Обычная прокрутка с края остаётся доступной.
    await tester.dragFrom(const Offset(790, 350), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
    await mode.settled;
    mode.dispose();
    scroll.dispose();
  });
}
