import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';

import 'package:typikon/dto/day_saints.dart';
import 'package:typikon/pages/current_day_memories_page.dart';
import 'package:typikon/store/index.dart';
import 'package:typikon/store/rootReducer.dart';

/// Святые дня из нашего каталога. Загрузка подменяется, чтобы показать список
/// без сети: элементы — кругляш (если сервер прислал) и имя, переход в досье
/// по слугу. Пустой день честно объясняет себя сам, отказ — «Повторить».

const _saints = DaySaints(date: "2026-01-16", saints: [
  DaySaint(
    slug: "ioann-predtecha",
    name: "Иоа́нн Предте́ча",
    roundelUrl: "https://cdn.dneslov.org/roundels/1/x.webp",
  ),
  DaySaint(slug: "savva-osvyashchennyi", name: "Са́вва О Свяще́нный"),
]);

void main() {
  Future<Store<AppState>> pump(
    WidgetTester tester, {
    required Future<DaySaints> Function(String date) loadSaints,
    Route<dynamic>? Function(RouteSettings settings)? onGenerateRoute,
  }) async {
    final store = Store<AppState>(appReducer, initialState: AppState.init());
    await tester.pumpWidget(StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: CurrentDayMemoriesPage(null, loadSaints: loadSaints),
        onGenerateRoute: onGenerateRoute,
      ),
    ));
    return store;
  }

  testWidgets("список: имя, кругляш у кого есть, переход по слугу", (tester) async {
    final asked = <String>[];
    Route<dynamic>? pushed;
    await pump(
      tester,
      loadSaints: (date) async {
        asked.add(date);
        return _saints;
      },
      onGenerateRoute: (settings) {
        if (settings.name == "/saints") {
          pushed = MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text("Досье")),
            settings: settings,
          );
          return pushed;
        }
        return null;
      },
    );
    await tester.pumpAndSettle();

    // Дата уходит как yyyy-MM-dd, ровно на выбранный день — без сдвига
    // старого стиля: его накладывает сервер.
    expect(asked.single, matches(RegExp(r"^\d{4}-\d{2}-\d{2}$")));

    expect(find.text("Иоа́нн Предте́ча"), findsOneWidget);
    expect(find.text("Са́вва О Свяще́нный"), findsOneWidget);

    // Кругляш есть у одного. Image.network сам запросит образ — сеть в тесте
    // не отвечает, и виджет честно схлопывается, не роняя страницу.
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, "https://cdn.dneslov.org/roundels/1/x.webp");

    await tester.tap(find.text("Иоа́нн Предте́ча"));
    await tester.pumpAndSettle();
    expect(pushed, isNotNull);
    expect(pushed!.settings.arguments, "ioann-predtecha");
    expect(find.text("Досье"), findsOneWidget);
  });

  testWidgets("пустой день объясняет себя и даёт выход на dneslov", (tester) async {
    await pump(
      tester,
      loadSaints: (_) async => const DaySaints(date: "2026-01-16", saints: []),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("В нашем каталоге пока нет связанных святых на этот день."),
      findsOneWidget,
    );
    // Пояснение не обещает лишнего и не выдаёт неполноту за поломку.
    expect(find.textContaining("88 из 653"), findsOneWidget);
    expect(find.text("Открыть dneslov.org"), findsOneWidget);
  });

  testWidgets("отказ сети — «Повторить», и повтор заново зовёт загрузку", (tester) async {
    var attempts = 0;
    await pump(
      tester,
      loadSaints: (_) async {
        attempts++;
        if (attempts == 1) throw Exception("нет сети");
        return _saints;
      },
    );
    await tester.pumpAndSettle();

    expect(find.text("Не удалось загрузить святых дня."), findsOneWidget);

    await tester.tap(find.text("Повторить"));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text("Иоа́нн Предте́ча"), findsOneWidget);
  });
}
