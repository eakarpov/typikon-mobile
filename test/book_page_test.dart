import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/dto/book.dart';
import 'package:typikon/pages/book_page.dart';

/// Отбор текстов книги по типу. Сервер таким отбором не занимается: сужается
/// уже загруженный список, порядок текстов сохраняется.
///
/// Загрузка книги подменяется, чтобы показать список без сети; у подменённых
/// текстов пустой `dneslovId`, и `Roundels` не ходит за кругликами.
void main() {
  const book = BookWithTexts(
    name: "Пролог (тест)",
    author: "",
    texts: [
      BookText(name: "Поучение о посте", id: "1", dneslovId: "", textType: "Teaching"),
      BookText(name: "Сказание о чуде", id: "2", dneslovId: "", textType: "Historic"),
      BookText(name: "Слово на праздник", id: "3", dneslovId: "", textType: "Praising"),
      BookText(name: "Сказание о плавании", id: "4", dneslovId: "", textType: "Historic"),
      BookText(name: "Алфавитная статья", id: "5", dneslovId: "", textType: "Reference"),
      BookText(name: "Текст без рода", id: "6", dneslovId: "", textType: ""),
    ],
  );

  const singleTypeBook = BookWithTexts(
    name: "Молитвы (тест)",
    author: "",
    texts: [
      BookText(name: "Молитва утренняя", id: "1", dneslovId: "", textType: "Prayer"),
      BookText(name: "Молитва вечерняя", id: "2", dneslovId: "", textType: "Prayer"),
    ],
  );

  Future<BookWithTexts> loadBook(String id) async => book;

  Future<void> pump(WidgetTester tester, {Future<BookWithTexts> Function(String id)? load}) =>
      tester.pumpWidget(MaterialApp(
        home: BookPage(null, id: "test", loadBook: load ?? loadBook),
      ));

  Future<void> pickType(WidgetTester tester, String label) async {
    // Чип после выбора носит подпись выбранного типа, а не «тип»: тапаем сам чип.
    await tester.tap(find.byType(Chip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets("сначала — весь список и чип отбора", (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text("Поучение о посте"), findsOneWidget);
    expect(find.text("Сказание о чуде"), findsOneWidget);
    expect(find.text("Текст без рода"), findsOneWidget);
    expect(find.text("тип"), findsOneWidget);
  });

  testWidgets("выбор типа сужает список, порядок сохраняется", (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await pickType(tester, "Исторические");

    expect(find.text("Сказание о чуде"), findsOneWidget);
    expect(find.text("Сказание о плавании"), findsOneWidget);
    // Другие типы и текст без рода отброшены.
    expect(find.text("Поучение о посте"), findsNothing);
    expect(find.text("Алфавитная статья"), findsNothing);
    expect(find.text("Текст без рода"), findsNothing);

    // Порядок первого появления в книге, а не алфавит.
    final first = tester.getTopLeft(find.text("Сказание о чуде"));
    final second = tester.getTopLeft(find.text("Сказание о плавании"));
    expect(first.dy, lessThan(second.dy));
  });

  testWidgets("сброс на «Все» возвращает полный список", (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await pickType(tester, "Справочные");
    expect(find.text("Алфавитная статья"), findsOneWidget);
    expect(find.text("Поучение о посте"), findsNothing);

    await pickType(tester, "Все");

    expect(find.text("Поучение о посте"), findsOneWidget);
    expect(find.text("Сказание о чуде"), findsOneWidget);
    expect(find.text("Слово на праздник"), findsOneWidget);
    expect(find.text("Сказание о плавании"), findsOneWidget);
    expect(find.text("Алфавитная статья"), findsOneWidget);
    expect(find.text("Текст без рода"), findsOneWidget);
  });

  testWidgets("пустой тип не предлагается как отбор, но остаётся в списке", (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text("тип"));
    await tester.pumpAndSettle();

    // В меню — только реальные типы, в порядке первого появления.
    expect(find.text("Учительные"), findsOneWidget);
    expect(find.text("Исторические"), findsOneWidget);
    expect(find.text("Похвальные"), findsOneWidget);
    expect(find.text("Справочные"), findsOneWidget);
    expect(find.text("Все"), findsOneWidget);
    // Пустая строка как пункт — нет.
    expect(find.byType(PopupMenuItem<Object?>), findsNWidgets(5));
  });

  testWidgets("книга с одним типом — без чипа: отбирать нечего", (tester) async {
    await pump(tester, load: (_) async => singleTypeBook);
    await tester.pumpAndSettle();

    expect(find.text("тип"), findsNothing);
    expect(find.text("Молитва утренняя"), findsOneWidget);
    expect(find.text("Молитва вечерняя"), findsOneWidget);
  });
}
