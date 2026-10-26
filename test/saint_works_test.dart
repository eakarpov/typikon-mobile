import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:typikon/dto/saint.dart';
import 'package:typikon/pages/saint_page.dart';
import 'package:typikon/pages/saint_corpus_page.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    Widget home, {
    void Function(RouteSettings)? onPush,
  }) async {
    tester.view.physicalSize = const Size(1200, 12000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      StoreProvider<AppState>(
        store: Store<AppState>(appReducer, initialState: AppState.init()),
        child: MaterialApp(
          onGenerateRoute: onPush == null
              ? null
              : (settings) {
                  onPush(settings);
                  return MaterialPageRoute(
                    builder: (_) =>
                        Scaffold(appBar: AppBar(), body: const Text('Открыто')),
                  );
                },
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'DTO accepts structured genres and keeps corpus-unavailable distinct from empty',
    () {
      final a = SaintDossier.fromJson({
        'name': 'Святой',
        'texts': [
          {'id': 't', 'name': 'Тропарь', 'contentType': 'Troparion'},
        ],
        'works': [],
      });
      expect(a.texts.single.genre, 'troparion');
    expect(SaintText.fromJson({'id':'s','name':'Служба','type':'Service'}).genre, 'service');
      expect(a.works, isEmpty);
      expect(
        SaintDossier.fromJson({'name': 'Святой', 'works': null}).works,
        isNull,
      );
    },
  );

  testWidgets(
    'genres include reading, hymns, canons, akathists and services with correct reader targets',
    (tester) async {
      final routes = <RouteSettings>[];
      final saint = SaintDossier(
        name: 'Святой',
        texts: const [SaintText(id: 'reading', name: 'Пролог')],
        mentions: const [SaintText(id: 'mention', name: 'Упоминание')],
        akathists: const [SaintAkathist(id: 'aka', title: 'Акафист святому')],
        works: const [
          SaintWork(
            id: '1',
            genre: 'troparion',
            reader: 'chant',
            title: 'Тропарь святому',
          ),
          SaintWork(
            id: '2',
            genre: 'kontakion',
            reader: 'chant',
            title: 'Кондак святому',
          ),
          SaintWork(
            id: '3',
            genre: 'magnification',
            reader: 'chant',
            title: 'Величание святому',
          ),
          SaintWork(
            id: 'canon',
            genre: 'canon',
            reader: 'canon',
            title: 'Канон святому',
          ),
          SaintWork(
            id: 'memory',
            genre: 'service',
            reader: 'service',
            title: 'Служба святому',
            language: 'cu_gr',
          ),
          SaintWork(
            id: '1',
            genre: 'troparion',
            reader: 'chant',
            title: 'Тропарь святому',
          ),
        ],
      );
      await open(
        tester,
        SaintPage(
          null,
          id: 'saint',
          loadDossier: (_) async => saint,
          loadLife: (_) async => const SaintLife(slug: 's'),
        ),
        onPush: routes.add,
      );
      await tester.tap(find.text('Тексты'));
      await tester.pumpAndSettle();
      for (final title in [
        'Четьи тексты',
        'Тропари',
        'Кондаки',
        'Величания',
        'Каноны',
        'Акафисты',
        'Службы',
        'Упоминания',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Тропарь святому'), findsOneWidget);
      for (final entry in {
        'Пролог': '/reading',
        'Тропарь святому': '/saint-text',
        'Канон святому': '/canons',
        'Акафист святому': '/akathists',
        'Служба святому': '/saint-text',
      }.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(routes.last.name, entry.value);
        if (entry.key == 'Служба святому') {
          final target = routes.last.arguments as SaintCorpusTarget;
          expect(target.reader, 'service');
          expect(target.id, 'memory');
          expect(target.language, 'cu_gr');
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('unavailable singing corpus leaves own readings visible', (
    tester,
  ) async {
    await open(
      tester,
      SaintPage(
        null,
        id: 'saint',
        loadDossier: (_) async => const SaintDossier(
          name: 'Святой',
          texts: [SaintText(id: 'r', name: 'Пролог')],
        ),
        loadLife: (_) async => const SaintLife(slug: 's'),
      ),
    );
    await tester.tap(find.text('Тексты'));
    await tester.pumpAndSettle();
    expect(find.text('Пролог'), findsOneWidget);
    expect(find.text('Певческий корпус временно недоступен.'), findsOneWidget);
  });

  testWidgets(
    'service reader shows resolved texts, missing fragments and links to complete canons',
    (tester) async {
      final routes = <RouteSettings>[];
      await open(
        tester,
        SaintCorpusPage(
          target: const SaintCorpusTarget(
            reader: 'service',
            id: 'memory',
            title: 'Служба',
          ),
          loader: () async => {
            'title': 'Святой',
            'book': 'menaion',
            'rows': [
              {
                'groupId': 1,
                'label': 'Тропарь',
                'service': 'vespers',
                'language': 'cu_gr',
                'text': 'Тропарь целиком',
              },
              {
                'groupId': 2,
                'label': 'Кондак',
                'service': 'matins',
                'language': 'cu_gr',
                'text': '',
              },
            ],
            'canons': [
              {'id': 'canon', 'tone': 3},
            ],
          },
        ),
        onPush: routes.add,
      );
      expect(find.text('Тропарь целиком', findRichText: true), findsOneWidget);
      expect(
        find.text('Текст этого фрагмента пока отсутствует в корпусе.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Канон · глас 3'));
      await tester.pumpAndSettle();
      expect(routes.single.name, '/canons');
      expect(routes.single.arguments, 'canon');
    },
  );
}
