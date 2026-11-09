import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/domain/companion.dart';
import 'package:typikon/store/companion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final entry = {
    'key': 'session',
    'snapshotId': 'snap',
    'nodeId': 'node',
    'contentHash': 'hash',
    'title': 'Вечерня',
    'nodeTitle': 'Ектения',
    'selection': {'mode': 'day', 'date': '2026-11-01', 'service': 'vespers'},
    'saved': <String, dynamic>{},
  };
  CompanionJson op(int revision, String action, {bool? done}) => {
    'id': 'op$revision',
    'revision': revision,
    'action': action,
    'entry': entry,
    if (done != null) 'done': done,
  };
  test('repeated operation cannot toggle or advance the saved place twice', () {
    var state = applyCompanionOperation(
      initialCompanionProgress(),
      op(0, 'save', done: true),
    );
    expect(companionMap(companionMap(state['entries'])['session'])['saved'], {
      'node': true,
    });
    expect(applyCompanionOperation(state, op(0, 'save', done: true)), state);
    state = applyCompanionOperation(state, op(1, 'position'));
    expect(companionMap(companionMap(state['entries'])['session'])['saved'], {
      'node': true,
    });
    expect(
      () => applyCompanionOperation(state, {
        ...op(0, 'position'),
        'id': 'new-stale-op',
      }),
      throwsStateError,
    );
  });
  test(
    'heard phrase search excludes secret prayers and keeps repeated occurrences',
    () {
      final service = {
        'nodes': [
          {
            'id': 'first',
            'title': 'Ектения',
            'lines': [
              {'text': 'Ми́ром Го́споду помо́лимся', 'audible': true},
            ],
          },
          {
            'id': 'secret',
            'title': 'Молитва',
            'lines': [
              {'text': 'Тайное слово', 'audible': false},
            ],
          },
          {
            'id': 'second',
            'title': 'Ектения',
            'lines': [
              {'text': 'Миром Господу помолимся', 'audible': true},
            ],
          },
        ],
      };
      expect(companionSearch(service, 'миром Господу').map((n) => n['id']), [
        'first',
        'second',
      ]);
      expect(companionSearch(service, 'тайное слово'), isEmpty);
      expect(companionNormalize('Святы́й'), companionNormalize('святыи'));
      expect(
        companionNormalize('Κύριε ἐλέησον'),
        companionNormalize('Κυριε ελεησον'),
      );
      expect(companionNormalize('мiра'), companionNormalize('мира'));
      expect(companionNormalize('Σωτήρ'), companionNormalize('σωτηρ'));
    },
  );
  test('text updates cannot silently move the bookmark', () {
    final service = {
      'nodes': [
        {'id': 'node', 'contentHash': 'new'},
      ],
    };
    expect(companionRestore(service, entry), isNull);
    expect(
      companionRestore(service, {...entry, 'contentHash': 'new'})?['id'],
      'node',
    );
  });
  test('imported dated service retains its liturgical day and standing', () {
    final selection = companionImportedSelection({
      'selection': {
        'mode': 'day',
        'date': '2026-11-01',
        'service': 'vespers',
        'stoyanie': 'eve',
        'use': {'rite': 'jerusalem', 'tradition': 'rus-synodal'},
      },
    });
    expect(selection['mode'], 'day');
    expect(selection['date'], '2026-11-01');
    expect(selection['part'], 'eve');
    expect(
      companionExcerpt(
        'начало ' * 50 + 'искомая фраза' + ' конец' * 50,
        'искомая фраза',
      ),
      contains('искомая фраза'),
    );
  });
  test(
    'exact line bookmarks survive edits elsewhere and reject changes to the marked line',
    () {
      final s = {
        'id': 'new',
        'nodes': [
          {
            'id': 'node',
            'contentHash': 'changed',
            'lines': [
              {'id': 'line-first', 'contentHash': 'first'},
              {'id': 'line-second', 'contentHash': 'second'},
            ],
          },
        ],
      };
      final e = {...entry, 'lineId': 'line-second', 'lineHash': 'second'};
      expect(companionRestore(s, e)?['id'], 'node');
      expect(companionRestore(s, {...e, 'lineHash': 'edited'}), isNull);
      final saved = applyCompanionOperation(initialCompanionProgress(), {
        ...op(0, 'position'),
        'entry': e,
      });
      expect(
        companionMap(companionMap(saved['entries'])['session'])['lineId'],
        'line-second',
      );
    },
  );
  test('an imported package cannot certify its own editorial bindings', () {
    final raw = jsonEncode({
      'schemaVersion': 1,
      'services': [
        {
          'id': 'snap',
          'sessionKey': 'session',
          'title': 'Вечерня',
          'guide': {
            'title': 'Вечерня',
            'summary': 'Служба',
            'detail': 'Текст',
            'author': 'Редакция',
            'sourceRefs': [],
          },
          'coverage': {},
          'nodes': [],
        },
      ],
      'sources': [],
      'trusted': true,
    });
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'companion.json',
          utf8.encode(raw).length,
          utf8.encode(raw),
        ),
      );
    final bytes = ZipEncoder().encode(archive);
    expect(CompanionBundle.fromPackage(bytes).data['trusted'], false);
    final old = Archive()
      ..addFile(ArchiveFile('ordo.json', 2, utf8.encode('{}')));
    expect(
      () => CompanionBundle.fromPackage(ZipEncoder().encode(old)),
      throwsFormatException,
    );
  });
  test(
    'logout erases private companion caches and preserves guest saves',
    () async {
      SharedPreferences.setMockInitialValues({
        'companion:user:a:progress': 'private',
        'companion:user:a:snapshot:x': 'text',
        'companion:guest:progress': 'guest',
        'companion:catalog': 'public',
      });
      await clearPrivateCompanionCache();
      final p = await SharedPreferences.getInstance();
      expect(p.getString('companion:user:a:progress'), isNull);
      expect(p.getString('companion:guest:progress'), 'guest');
      expect(p.getString('companion:catalog'), 'public');
    },
  );
  test('owner changes prevent saving another account state', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = CompanionRepository('a', owner: () => 'b');
    expect(
      () => repo.save({'state': initialCompanionProgress(), 'queue': []}),
      throwsStateError,
    );
  });
}
