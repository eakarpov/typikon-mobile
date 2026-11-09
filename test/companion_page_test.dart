import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/domain/companion.dart';
import 'package:typikon/pages/companion_page.dart';
import 'package:typikon/store/companion.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

final note = {
  'title': 'Ектения',
  'summary': 'Общее прошение',
  'detail': 'Ответы на прошения',
  'author': 'Редакция Typikon',
  'checkedAt': '2026-11-02',
  'sourceRefs': [],
};
final selection = {
  'mode': 'day',
  'date': '2026-11-01',
  'service': 'vespers',
  'part': 'eve',
};
final service = <String, dynamic>{
  'id': 'snapshot',
  'sessionKey': 'session',
  'title': 'Вечерня',
  'guide': note,
  'civil': '2026-10-31',
  'partLabel': 'Вечер',
  'selection': selection,
  'facts': [],
  'rules': [],
  'assemblyStatus': 'Порядок сборщика',
  'coverage': {
    'structure': true,
    'texts': true,
    'explanations': true,
    'translations': 0,
    'translationTotal': 2,
    'missing': [],
    'errors': [],
  },
  'nodes': List.generate(
    2,
    (i) => {
      'id': 'node$i',
      'title': 'Ектения ${i + 1}',
      'contentHash': 'body$i',
      'explanation': note,
      'evidence': [],
      'wordSenses': [],
      'lines': [
        {
          'id': 'line$i',
          'text': 'Миром Господу помолимся',
          'audible': true,
          'repeatCount': 1,
          'translations': [],
        },
      ],
    },
  ),
};
final bundle = <String, dynamic>{
  'schemaVersion': 1,
  'corpusVersion': 'test',
  'editorialVersion': '1',
  'sources': [],
  'services': [service],
  'trusted': true,
};
final catalog = <String, dynamic>{
  'schemaVersion': 1,
  'ustavy': [],
  'services': [
    {
      'id': 'vespers-study',
      'family': 'vespers',
      'title': 'Вечерня',
      'guide': note,
    },
  ],
};

class Repository extends CompanionRepository {
  bool online;
  Repository({this.online = true}) : super(null, owner: () => null);
  @override
  Future<dynamic> request(
    String method,
    String path, {
    CompanionJson? body,
    bool personal = false,
  }) async {
    if (!online) throw StateError('Нет сети');
    return path == '/catalog' ? catalog : companionCopy(bundle);
  }

  @override
  Future<CompanionJson> day(String date, String? ustav) async {
    if (!online) throw StateError('Нет сети');
    return {
      'variants': [
        {
          'key': 'default',
          'label': 'Обычный',
          'stoyaniya': [
            {
              'key': 'eve',
              'civil': '2026-10-31',
              'part_label': 'Вечер',
              'services': [
                {'key': 'vespers', 'label': 'Вечерня'},
              ],
            },
            {
              'key': 'second',
              'civil': '2026-11-01',
              'part_label': 'День',
              'services': [
                {'key': 'vespers', 'label': 'Вечерня'},
              ],
            },
          ],
        },
      ],
    };
  }
}

Future<void> pump(WidgetTester t, Repository repo) async {
  t.view.physicalSize = const Size(1200, 2400);
  t.view.devicePixelRatio = 1;
  await t.pumpWidget(
    StoreProvider<AppState>(
      store: Store<AppState>(appReducer, initialState: AppState.init()),
      child: MaterialApp(
        home: CompanionPage(
          repository: repo,
          initialSelection: companionCopy(selection),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'service occurrence, civil date and manual place survive a cold offline open',
    (t) async {
      final repo = Repository();
      await pump(t, repo);
      await t.tap(find.text('Открыть Спутник'));
      await t.pumpAndSettle();
      expect(find.textContaining('Совершение: 2026-10-31'), findsOneWidget);
      expect(
        companionMap(companionMap((await repo.load())['state'])['entries']),
        isEmpty,
      );
      expect((await repo.lastViewed())?['title'], 'Вечерня');
      await t.ensureVisible(find.text('Во время'));
      await t.tap(find.text('Во время'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Далее'));
      await t.tap(find.text('Далее'));
      await t.pumpAndSettle();
      final saved = await repo.load();
      final e = companionMap(
        companionMap(companionMap(saved['state'])['entries'])['session'],
      );
      expect(e['nodeId'], 'node1');
      await t.ensureVisible(find.text('Сохранить часть'));
      await t.tap(find.text('Сохранить часть'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      repo.online = false;
      await pump(t, repo);
      await t.tap(find.text('Сохранённое'));
      await t.pumpAndSettle();
      await t.tap(find.text('Вечерня').first);
      await t.pumpAndSettle();
      expect(find.textContaining('Сохранённая копия.'), findsOneWidget);
      expect(find.text('Убрать сохранение'), findsOneWidget);
      expect(find.text('Ектения 2'), findsWidgets);
      await t.pumpWidget(const SizedBox());
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    },
  );
  test('selection signature ignores optional empties and insertion order', () {
    expect(
      companionSignature({'service': 'vespers', 'mode': 'day', 'part': null}),
      companionSignature({
        'mode': 'day',
        'service': 'vespers',
        'ordo': 'previous-study-template',
      }),
    );
  });
}
