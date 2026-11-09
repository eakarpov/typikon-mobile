import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/domain/study.dart';
import 'package:typikon/pages/study_page.dart';
import 'package:typikon/store/study.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

final target = {'kind': 'text', 'id': 'source', 'edition': 'edition'};
final fixture = {
  'target': target,
  'title': 'Проверочная книга',
  'language': 'cu_gr',
  'edition': 'Проверочное издание',
  'sourceHash': 'sourcehash',
  'metadata': <String, dynamic>{},
  'footnotes': ['Проверочная сноска'],
  'missing': <dynamic>[],
  'blocks': [
    for (var i = 0; i < 3; i++)
      {
        'id': 'block$i',
        'hash': 'hash$i',
        'index': i,
        'text': 'Абзац ${i + 1}. Проверочный текст для вдумчивого чтения.',
      },
  ],
};

class Repo extends StudyRepository {
  final Map<String, dynamic> data;
  bool online = true;
  Repo(this.data) : super(null, owner: () => null);
  @override
  Future<dynamic> cached(String key) async =>
      data[key] == null ? null : jsonDecode(jsonEncode(data[key]));
  @override
  Future<void> cache(String key, dynamic value) async {
    data[key] = jsonDecode(jsonEncode(value));
  }

  @override
  Future<List<StudyJson>> saved() async => [];
  @override
  Future<dynamic> request(String method, String path, [StudyJson? body]) async {
    if (!online) throw const SocketException('offline');
    if (path == 'catalog')
      return {'books': <dynamic>[], 'editions': <dynamic>[]};
    if (path == 'routes') return {'routes': <dynamic>[]};
    if (path == 'material') return fixture;
    if (path == 'related')
      return {'relations': <dynamic>[], 'notice': 'Подготовленные связи'};
    throw StateError(path);
  }
}

class BookRepo extends Repo {
  BookRepo(super.data);
  @override
  Future<dynamic> request(String method, String path, [StudyJson? body]) async {
    if (!online) throw const SocketException('offline');
    if (path == 'catalog')
      return {
        'books': [
          {
            'id': 'book',
            'title': 'Книга с главами',
            'language': 'cu_gr',
            'available': 2,
          },
        ],
        'editions': [],
      };
    if (path == 'catalog?book=book')
      return {
        'book': {'id': 'book', 'title': 'Книга с главами'},
        'texts': [
          for (var n = 1; n <= 2; n++)
            {
              'id': 'chapter$n',
              'title': 'Глава $n',
              'target': {'kind': 'text', 'id': 'chapter$n'},
            },
        ],
      };
    if (path == 'material') {
      final t = studyMap(body?['target']);
      return {
        ...fixture,
        'target': {...t, 'edition': 'book'},
        'title': t['id'] == 'chapter1' ? 'Глава 1' : 'Глава 2',
        'metadata': {'bookId': 'book'},
      };
    }
    return super.request(method, path, body);
  }
}

Future<void> pump(WidgetTester t, Repo repo, {bool openInitial = true}) async {
  t.view.physicalSize = const Size(1200, 2600);
  t.view.devicePixelRatio = 1;
  await t.pumpWidget(
    StoreProvider<AppState>(
      store: Store<AppState>(appReducer, initialState: AppState.init()),
      child: MaterialApp(
        home: StudyPage(
          repository: repo,
          initialTarget: openInitial ? target : null,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'book chapters keep their own order and resume after a cold offline start',
    (t) async {
      final shared = <String, dynamic>{}, repo = BookRepo(shared);
      await pump(t, repo, openInitial: false);
      await t.tap(find.text('Оглавление'));
      await t.pumpAndSettle();
      await t.tap(find.text('Глава 1'));
      await t.pumpAndSettle();
      expect(find.text('Следующий материал'), findsOneWidget);
      await t.ensureVisible(find.text('Следующий материал'));
      await t.tap(find.text('Следующий материал'));
      await t.pumpAndSettle();
      expect(find.text('Глава 2'), findsOneWidget);
      final positions = studyList(
        studyMap(studyMap(await repo.cached('personal'))['state'])['positions'],
      );
      expect(
        positions.singleWhere(
          (p) => p['collectionId'] == 'book-book',
        )['itemId'],
        'chapter2',
      );
      await t.pumpWidget(const SizedBox());
      final cold = BookRepo(shared)..online = false;
      await pump(t, cold, openInitial: false);
      await t.tap(find.text('Моё чтение'));
      await t.pumpAndSettle();
      await t.tap(find.text('Книга с главами'));
      await t.pumpAndSettle();
      expect(find.text('Глава 2'), findsOneWidget);
      expect(find.text('Предыдущий материал'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    },
  );
  testWidgets(
    'a question is saved with its source and never marks the reading as completed',
    (t) async {
      final repo = Repo({});
      await pump(t, repo);
      expect(find.text('Проверочная книга'), findsOneWidget);
      await t.ensureVisible(find.text('Материалы и мои записи'));
      await t.tap(find.text('Материалы и мои записи'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Сохранить вопрос'));
      await t.tap(find.text('Сохранить вопрос'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'Комментарий / вопрос'),
        'Что означает этот отрывок?',
      );
      await t.tap(find.widgetWithText(TextButton, 'Сохранить'));
      await t.pumpAndSettle();
      final state = studyMap(studyMap(await repo.cached('personal'))['state']);
      expect(studyList(state['records']).single['kind'], 'question');
      expect(
        studyList(state['records']).single['target']['quote'],
        contains('Абзац 1'),
      );
      expect(
        studyList(state['positions']).where((p) => p['status'] == 'read'),
        isEmpty,
      );
      await t.pumpWidget(const SizedBox());
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    },
  );
  testWidgets('manual source position survives a cold offline reader', (
    t,
  ) async {
    final shared = <String, dynamic>{};
    final repo = Repo(shared);
    await pump(t, repo);
    await t.ensureVisible(find.text('Место 2'));
    await t.tap(find.text('Место 2'));
    await t.pump();
    await t.ensureVisible(find.text('Запомнить место'));
    await t.pumpAndSettle();
    await t.tap(find.text('Запомнить место'));
    await t.pumpAndSettle();
    expect(
      studyList(
        studyMap(studyMap(await repo.cached('personal'))['state'])['positions'],
      ),
      isNotEmpty,
    );
    await t.pumpWidget(const SizedBox());
    final cold = Repo(shared)..online = false;
    await pump(t, cold);
    expect(find.text('Проверочная книга'), findsOneWidget);
    expect(
      studyMap(
        studyList(
          studyMap(
            studyMap(await cold.cached('personal'))['state'],
          )['positions'],
        ).single['target'],
      )['blockId'],
      'block1',
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
}
