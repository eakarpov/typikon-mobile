import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/domain/study.dart';
import 'package:typikon/store/study.dart';
import 'package:typikon/apiMapper/v2/errors.dart';

StudyJson source(String text) => {
  'target': {'kind': 'text', 'id': 'source', 'edition': 'edition'},
  'title': 'Книга',
  'sourceHash': studyFingerprint(text),
  'blocks': [
    {
      'id': 'b-${studyFingerprint(text)}-0',
      'hash': studyFingerprint(text),
      'text': text,
      'index': 0,
    },
  ],
  'missing': [],
};
void main() {
  test('logout retains unsent work only for the original account', () async {
    final dir = await Directory.systemTemp.createTemp('study-logout-');
    addTearDown(() => dir.delete(recursive: true));
    String? current = 'alice';
    final alice = StudyRepository('alice', root: dir, owner: () => current);
    await alice.cache('personal', {
      'state': {
        'records': [
          {'id': 'note', 'note': 'Не отправлено'},
        ],
      },
      'queue': [
        {'opId': 'unsent'},
      ],
      'conflicts': [],
    });
    await alice.cache('material:source', source('Текст'));
    await clearPrivateStudyCache(root: dir);
    current = null;
    final guest = StudyRepository(null, root: dir, owner: () => current);
    expect(await guest.cached('personal'), isNull);
    current = 'bob';
    final bob = StudyRepository('bob', root: dir, owner: () => current);
    expect(await bob.cached('personal'), isNull);
    current = 'alice';
    expect(
      studyList(
        studyMap(await alice.cached('personal'))['queue'],
      ).single['opId'],
      'unsent',
    );
    expect(await alice.cached('material:source'), isNull);
    await alice.cache('personal', {
      'state': emptyStudy(),
      'queue': <dynamic>[],
      'conflicts': <dynamic>[],
    });
    await clearPrivateStudyCache(root: dir);
    expect(await alice.cached('personal'), isNull);
  });
  test('an explicit correction can replace a rejected source save', () async {
    final root = await Directory.systemTemp.createTemp('study-refused-');
    addTearDown(() => root.delete(recursive: true));
    var reject = true;
    final repo = StudyRepository(
      'owner',
      root: root,
      owner: () => 'owner',
      transport: (method, path, body) async {
        if (reject) throw const ApiNotFoundException('Уточните место');
        return {
          'userId': 'owner',
          'value': {...studyMap(body?['value']), 'revision': 1},
        };
      },
    );
    StudyJson doc = {
      'state': emptyStudy(),
      'queue': <dynamic>[],
      'conflicts': <dynamic>[],
    };
    doc = await repo.operate(doc, 'records', {
      'id': 'n',
      'revision': 0,
      'kind': 'note',
      'note': 'Мысль',
      'target': {'kind': 'text', 'id': 'old'},
    });
    await expectLater(repo.sync(doc), throwsA(isA<ApiNotFoundException>()));
    reject = false;
    doc = await repo.operate(doc, 'records', {
      'id': 'n',
      'revision': 0,
      'kind': 'note',
      'note': 'Мысль',
      'target': {'kind': 'text', 'id': 'corrected'},
    });
    expect(studyList(doc['queue']).length, 1);
    doc = await repo.sync(doc);
    expect(studyList(doc['queue']), isEmpty);
    expect(
      studyList(studyMap(doc['state'])['records']).single['target']['id'],
      'corrected',
    );
  });
  test('portable Unicode search and source fingerprint match the web', () {
    expect(studyFingerprint('hello'), '4f9f2cab');
    expect(studyNormalize('Κύριε ἐλέησον'), studyNormalize('Κυριε ελεησον'));
    expect(studyNormalize('мiра'), studyNormalize('мира'));
  });
  test(
    'exact source position cannot migrate to a different edition or changed text',
    () {
      final m = source('Исходная мысль'),
          t = studyTargetAt(m, studyList(m['blocks']).first, quote: 'мысль');
      expect(studyLocate(m, t), isNotNull);
      expect(studyLocate(source('Другая мысль'), t), isNull);
      expect(
        studyLocate({
          ...m,
          'target': {'kind': 'text', 'id': 'source', 'edition': 'other'},
        }, t),
        isNull,
      );
    },
  );
  test('ambiguous repeated quotation is not guessed', () {
    final m = {
      'target': {'kind': 'text', 'id': 'source'},
      'blocks': [
        {'id': 'first', 'text': 'дубль дубль'},
        {'id': 'second', 'text': 'дубль'},
      ],
    };
    expect(
      studyLocate(m, {'kind': 'text', 'id': 'source', 'quote': 'дубль'}),
      isNull,
    );
  });
  test('Markdown export retains thought, quotation and source address', () {
    final state = emptyStudy();
    state['records'] = [
      {
        'kind': 'question',
        'note': 'Почему?',
        'target': {'kind': 'text', 'id': 'source', 'quote': 'Цитата'},
      },
    ];
    final text = studyMarkdown(state);
    expect(text, contains('Почему?'));
    expect(text, contains('Цитата'));
    expect(text, contains('/study?target='));
  });
  test('guest state and material survive cold offline creation', () async {
    final root = await Directory.systemTemp.createTemp('study-offline-');
    addTearDown(() => root.delete(recursive: true));
    final repo = StudyRepository(
      null,
      owner: () => null,
      root: root,
      transport: (m, p, b) async {
        if (p == 'material') return source('Сохранённый текст');
        throw const SocketException('offline');
      },
    );
    await repo.material({'kind': 'text', 'id': 'source', 'edition': 'edition'});
    var doc = await repo.load();
    doc = await repo.operate(doc, 'records', {
      'id': 'record',
      'revision': 0,
      'kind': 'question',
      'questionStatus': 'open',
      'target': studyTargetAt(
        source('Сохранённый текст'),
        studyList(source('Сохранённый текст')['blocks']).first,
      ),
      'note': 'Вопрос',
      'tags': [],
    });
    final cold = StudyRepository(
      null,
      owner: () => null,
      root: root,
      transport: (m, p, b) async => throw const SocketException('offline'),
    );
    expect(
      studyList(
        studyMap((await cold.load())['state'])['records'],
      ).single['note'],
      'Вопрос',
    );
    expect(
      (await cold.material({
        'kind': 'text',
        'id': 'source',
        'edition': 'edition',
      }))['title'],
      'Книга',
    );
    expect((doc['queue'] as List), isEmpty);
  });
  test('owner switch blocks late responses and writes', () async {
    final root = await Directory.systemTemp.createTemp('study-owner-');
    addTearDown(() => root.delete(recursive: true));
    String? owner = 'alice';
    final repo = StudyRepository(
      'alice',
      owner: () => owner,
      root: root,
      transport: (m, p, b) async {
        owner = 'bob';
        return source('Текст');
      },
    );
    await expectLater(
      repo.material({'kind': 'text', 'id': 'source'}),
      throwsStateError,
    );
  });
  test('conflicts preserve local and server versions', () async {
    final root = await Directory.systemTemp.createTemp('study-conflict-');
    addTearDown(() => root.delete(recursive: true));
    final repo = StudyRepository(
      'alice',
      owner: () => 'alice',
      root: root,
      transport: (m, p, b) async => throw StudyConflict({
        'id': 'record',
        'note': 'Серверная версия',
        'revision': 2,
      }),
    );
    StudyJson doc = {
      'state': emptyStudy(),
      'queue': <dynamic>[],
      'conflicts': <dynamic>[],
    };
    doc = await repo.operate(doc, 'records', {
      'id': 'record',
      'revision': 1,
      'kind': 'note',
      'note': 'Моя версия',
      'target': {'kind': 'text', 'id': 'source'},
    });
    final result = await repo.sync(doc);
    expect(
      studyList(result['conflicts']).single['value']['note'],
      'Моя версия',
    );
    expect(
      studyList(result['conflicts']).single['remote']['note'],
      'Серверная версия',
    );
    expect(studyList(result['queue']), isEmpty);
  });
}
