import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:typikon/components/drawer_menu_sections.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

void main() {
  testWidgets(
    'вход доступен сверху, гостевой Помянник видим и не открывается',
    (tester) async {
      final store = Store<AppState>(appReducer, initialState: AppState.init());
      await tester.pumpWidget(
        StoreProvider<AppState>(
          store: store,
          child: MaterialApp(
            home: const Scaffold(
              body: SingleChildScrollView(child: DrawerMenuSections()),
            ),
            routes: {
              '/pomyannik': (_) =>
                  const Scaffold(body: Text('Имена помянника')),
            },
          ),
        ),
      );

      final signIn = find.widgetWithText(ListTile, 'Войти через Google');
      expect(tester.widget<ListTile>(signIn).onTap, isNotNull);
      expect(
        tester.getTopLeft(signIn).dy,
        lessThan(tester.getTopLeft(find.text('Главная страница')).dy),
      );

      final memorial = find.widgetWithText(ListTile, 'Помянник');
      await tester.ensureVisible(memorial);
      expect(tester.widget<ListTile>(memorial).enabled, isFalse);
      expect(tester.widget<ListTile>(memorial).onTap, isNull);
      expect(find.text('Доступен после входа'), findsOneWidget);
      await tester.tap(memorial);
      await tester.pumpAndSettle();
      expect(find.text('Имена помянника'), findsNothing);

      // Авторизация меняет уже открытое меню, а не только следующий запуск.
      store.dispatch(
        SignInSuccessAction(
          userId: 'reader',
          email: 'reader@example.com',
          name: 'Читатель',
        ),
      );
      await tester.pumpAndSettle();
      expect(signIn, findsNothing);
      expect(find.text('Доступен после входа'), findsNothing);
      expect(tester.widget<ListTile>(memorial).enabled, isTrue);
      await tester.ensureVisible(memorial);
      await tester.tap(memorial);
      await tester.pumpAndSettle();
      expect(find.text('Имена помянника'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      store.dispatch(SignOutAction());
      await tester.pumpAndSettle();
      expect(signIn, findsOneWidget);
      expect(tester.widget<ListTile>(memorial).enabled, isFalse);
      expect(find.text('Поданные записки'), findsNothing);
    },
  );
}
