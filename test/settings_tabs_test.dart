import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/pages/settings_page.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';
import 'package:typikon/store/pomyannik_cache.dart';

void main() {
  Future<Store<AppState>> open(
    WidgetTester tester, {
    bool signedIn = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final initial = AppState.init();
    final store = Store<AppState>(
      appReducer,
      initialState: AppState(
        common: initial.common,
        settings: initial.settings,
        auth: AuthState(
          isSignedIn: signedIn,
          email: signedIn ? 'test@example.com' : null,
        ),
      ),
    );
    await tester.pumpWidget(
      StoreProvider<AppState>(
        store: store,
        child: MaterialApp(home: SettingsPage(null)),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets(
    'switching tabs retains display and offline preferences on a narrow screen',
    (tester) async {
      final store = await open(tester);
      final displayScroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('settings-display')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byType(Slider),
        200,
        scrollable: displayScroll,
      );
      tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(24);
      await tester.pumpAndSettle();
      expect(store.state.settings.fontSize, 24);
      await tester.tap(find.text('Система'));
      await tester.pumpAndSettle();
      final preload = find.widgetWithText(
        SwitchListTile,
        'Заранее скачивать чтения дня',
      );
      await tester.ensureVisible(preload);
      await tester.tap(preload);
      await tester.pumpAndSettle();
      expect(store.state.settings.isPreloadEnabled, true);
      await tester.tap(find.text('Отображение'));
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 24);
      await tester.tap(find.text('Система'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(preload).value, true);
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'notification controls remain usable in system tab for signed-in users',
    (tester) async {
      await open(tester, signedIn: true);
      await tester.tap(find.text('Система'));
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('settings-system')),
            matching: find.byType(Scrollable),
          )
          .first;
      final names = find.widgetWithText(
        SwitchListTile,
        'Показывать имена в уведомлении',
      );
      await tester.scrollUntilVisible(names, 400, scrollable: scroll);
      final app = tester.widget<RadioListTile<String>>(
        find.widgetWithText(RadioListTile<String>, 'Приложение'),
      );
      final server = tester.widget<RadioListTile<String>>(
        find.widgetWithText(RadioListTile<String>, 'Сервер'),
      );
      expect(app.value, 'device');
      expect(app.onChanged, null);
      expect(server.value, 'server');
      expect(server.onChanged, null);
      expect(tester.widget<SwitchListTile>(names).onChanged, null);
      expect(await remindersEnabled(), false);
      expect(tester.takeException(), null);
    },
  );
}
