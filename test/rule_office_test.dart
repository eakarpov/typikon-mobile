import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/pages/rule_office_page.dart';
import 'package:typikon/dto/corpus.dart';
import 'package:typikon/dto/text.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

void main() {
  test('канон вставляется в книжную рубрику', () {
    expect(
      splitOfficeAtCanon(
        'До\n{k|Таже чтем канон Троице из Октоиха во глас недели}\nПосле',
      ),
      ('До\n', '\nПосле'),
    );
    expect(
      splitOfficeAtCanon(
        'До{k|Посем глаголем канон рядовый Богородице Октоиха или святому по уставу.}После',
      ),
      ('До', 'После'),
    );
    expect(splitOfficeAtCanon('Вседневная полунощница без канона'), isNull);
  });
  testWidgets('текст до канона → песни канона → текст после; одна прокрутка', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const canon = CanonDetail(
      canon: Canon(id: 'c', memory: 'Троице', language: 'cu_gr'),
      odes: [
        CanonOde(
          ode: 1,
          irmos: [CanonLine(text: 'Ирмос тест')],
          troparia: [CanonLine(text: 'Тропарь тест')],
        ),
      ],
    );
    final reading = Reading.fromJson({
      'id': 't',
      'name': 'Полунощница',
      'content':
          'Начало службы\n\n{k|Таже чтем канон Троице из Октоиха во глас недели}\n\nКонец службы',
    }, null);
    await tester.pumpWidget(
      StoreProvider<AppState>(
        store: Store<AppState>(appReducer, initialState: AppState.init()),
        child: MaterialApp(
          home: RuleOfficePage(
            target: const RuleOfficeTarget(
              textId: 't',
              title: 'Полунощница воскресная',
              canonId: 'c',
              tone: 3,
              needsCanon: true,
            ),
            loader: () async => RuleOfficeData(reading, canon),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ирмос тест', findRichText: true), findsOneWidget);
    expect(find.text('Тропарь тест', findRichText: true), findsOneWidget);
    final start = tester.getTopLeft(
      find.textContaining('Начало службы', findRichText: true),
    );
    final mid = tester.getTopLeft(find.text('Ирмос тест', findRichText: true));
    final end = tester.getTopLeft(
      find.textContaining('Конец службы', findRichText: true),
    );
    expect(start.dy, lessThan(mid.dy));
    expect(mid.dy, lessThan(end.dy));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
