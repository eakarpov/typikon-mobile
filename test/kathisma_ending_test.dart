import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/components/kathisma_ending.dart';
import 'package:typikon/dto/bible.dart';
import 'package:typikon/dto/posledovanie.dart';
import 'package:typikon/pages/kathisma_page.dart';
import 'package:typikon/pages/psalter_serial_page.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

Future<Posledovanie> ending(int n) async => Posledovanie(
  rows: [
    const PosledovanieRow(
      label: 'Трисвятое по Отче наш',
      text: 'Святый Боже',
      repeatCount: 3,
    ),
    PosledovanieRow(label: 'Тропари по $n-й кафизме', text: 'Тропарь $n'),
    const PosledovanieRow(text: 'Господи, помилуй', repeatCount: 40),
    PosledovanieRow(label: 'Молитва по $n-й кафизме', text: 'Молитва $n'),
  ],
);
Future<BibleChapter> chapter(int n) async => BibleChapter.fromJson({
  'book': {'id': 'psaltir'},
  'chapter': n,
  'verses': [
    for (final v in n == 118 ? [1, 72, 131, 176] : [1])
      {
        'verse': v,
        'editions': [
          {'chapter': n, 'verse': v, 'content': 'Псалом $n стих $v'},
        ],
      },
  ],
});
Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    StoreProvider<AppState>(
      store: Store<AppState>(appReducer, initialState: AppState.init()),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('книжный порядок и повторения приходят из API', (tester) async {
    await pump(tester, KathismaEnding(number: 1, loader: ending));
    final strings = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(
      strings.indexOf('Святый Боже'),
      lessThan(strings.indexOf('Тропарь 1')),
    );
    expect(
      strings.indexOf('Тропарь 1'),
      lessThan(strings.indexOf('Молитва 1')),
    );
    expect(find.text('по 40'), findsOneWidget);
    expect(find.text('по 3'), findsOneWidget);
    expect(find.textContaining('Со духи'), findsNothing);
  });
  testWidgets('переключение номера не оставляет молитву предыдущей кафизмы', (
    tester,
  ) async {
    await pump(tester, KathismaEnding(number: 1, loader: ending));
    await pump(tester, KathismaEnding(number: 20, loader: ending));
    expect(find.text('Молитва 1'), findsNothing);
    expect(find.text('Молитва 20'), findsOneWidget);
  });
  testWidgets(
    'при сбое не подставляется лития; повтор загружает нужную кафизму',
    (tester) async {
      var calls = 0;
      await pump(
        tester,
        KathismaEnding(
          number: 6,
          loader: (n) async {
            if (++calls == 1) throw Exception('offline');
            return ending(n);
          },
        ),
      );
      expect(
        find.textContaining('Не удалось загрузить тропари'),
        findsOneWidget,
      );
      expect(find.textContaining('Боже духов'), findsNothing);
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Молитва 6'), findsOneWidget);
    },
  );
  for (final n in [1, 6, 17, 20]) {
    testWidgets('обычная кафизма $n получает своё окончание без входа', (
      tester,
    ) async {
      final calls = <int>[];
      await tester.pumpWidget(
        StoreProvider<AppState>(
          store: Store<AppState>(appReducer, initialState: AppState.init()),
          child: MaterialApp(
            home: KathismaPage(
              number: n,
              loadChapter: chapter,
              endingLoader: (number) {
                calls.add(number);
                return ending(number);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, [n]);
      expect(find.text('Молитва $n'), findsOneWidget);
      expect(find.text('Войти'), findsNothing);
    });
  }
  for (final pair in [(8, 1), (45, 6), (118, 17), (150, 20), (151, 0)]) {
    testWidgets('подряд: псалом ${pair.$1} заканчивает кафизму ${pair.$2}', (
      tester,
    ) async {
      final calls = <int>[];
      await tester.pumpWidget(
        StoreProvider<AppState>(
          store: Store<AppState>(appReducer, initialState: AppState.init()),
          child: MaterialApp(
            home: PsalterSerialPage(
              chapter: pair.$1,
              loadChapter: chapter,
              endingLoader: (number) {
                calls.add(number);
                return ending(number);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, pair.$2 == 0 ? [] : [pair.$2]);
      if (pair.$2 != 0) expect(find.text('Молитва ${pair.$2}'), findsOneWidget);
    });
  }
}
