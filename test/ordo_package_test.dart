import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:typikon/api/ordo.dart';
import 'package:typikon/apiMapper/ordo.dart';
import 'package:typikon/apiMapper/ordo_scripture.dart';
import 'package:typikon/apiMapper/v2/errors.dart';
import 'package:typikon/domain/ordo_package.dart';
import 'package:typikon/dto/bible.dart';

List<int> pack(Map<String, dynamic> parts) {
  final archive = Archive();
  for (final entry in parts.entries) {
    final bytes = utf8.encode(
      entry.value is String ? entry.value as String : jsonEncode(entry.value),
    );
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive);
}

Map<String, dynamic> fixture({bool legacy = false}) => {
  'manifest.json': {
    'format': 'posledovanie',
    'spec_version': legacy ? '1.0' : '1.1',
    'scope': {
      'date': '2026-10-25',
      if (!legacy) 'services': ['matins'],
    },
  },
  'ordo.json': legacy ? service() : {'date': '2026-10-25'},
  if (!legacy) 'services/matins.json': service(),
  'addresses.json': {
    'lines': [
      for (var i = 0; i < 4; i++)
        {
          if (!legacy) 'service': 'matins',
          'step': 0,
          'item': i,
          if (i < 2) 'body': {'in': 'texts/book.jsonl', 'line': 1 - i},
          if (i == 2) 'body': {'absent': 'rights'},
          if (i == 3) ...{
            'body': {'absent': 'external'},
            'address': 'bible:psaltir.1.1-2',
          },
        },
    ],
  },
  'texts/book.jsonl':
      '${jsonEncode({'text': 'Текст первый'})}\n${jsonEncode({'text': 'Текст второй'})}\n',
};
Map<String, dynamic> service() => {
  'key': 'matins',
  'label': 'Утреня',
  'steps': [
    {
      'label': 'Начало',
      'items': [
        for (var i = 0; i < 4; i++) {if (i < 2) 'address': 'повторённый-адрес'},
      ],
    },
  ],
};
List<String> texts(OrdoPackage p) => p.reading.services
    .expand((s) => s.sections)
    .expand((s) => s.texts)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final legacy in [true, false]) {
    test(
      'формат ${legacy ? '1.0' : '1.1'}: тела по месту, причины отсутствия',
      () {
        final p = OrdoPackage.decode(pack(fixture(legacy: legacy)));
        expect(p.date, '2026-10-25');
        expect(p.reading.services.single.title, 'Утреня');
        expect(texts(p).take(2), ['Текст второй', 'Текст первый']);
        expect(texts(p), contains('Текст не предоставлен правообладателем.'));
      },
    );
  }
  test(
    'неподдерживаемая версия и отсутствующая служба не маскируются пустым днём',
    () {
      final f = fixture();
      (f['manifest.json'] as Map)['spec_version'] = '2.0';
      expect(() => OrdoPackage.decode(pack(f)), throwsFormatException);
      final missing = fixture()..remove('services/matins.json');
      expect(() => OrdoPackage.decode(pack(missing)), throwsFormatException);
    },
  );
  test('битая ссылка на строку отклоняется', () {
    final f = fixture();
    ((f['addresses.json'] as Map)['lines'][0]['body'] as Map)['line'] = 99;
    expect(() => OrdoPackage.decode(pack(f)), throwsFormatException);
  });
  test('порядок служб берётся из манифеста, повторы сохраняются', () {
    final f = fixture();
    (f['manifest.json'] as Map)['scope']['services'] = ['vespers', 'matins'];
    f['services/vespers.json'] = {
      'label': 'Вечерня',
      'steps': [
        {'text': 'Повтор'},
        {'text': 'Повтор'},
      ],
    };
    final p = OrdoPackage.decode(pack(f));
    expect(p.reading.services.map((s) => s.title), ['Вечерня', 'Утреня']);
    expect(texts(p).take(2), ['Повтор', 'Повтор']);
  });
  test('unset сохраняет книжную подсказку', () {
    final f = fixture();
    (f['services/matins.json'] as Map)['steps'][0]['items'][2]['text'] =
        'Выберите текст';
    (f['addresses.json'] as Map)['lines'][2]['body'] = {'absent': 'unset'};
    expect(texts(OrdoPackage.decode(pack(f))), contains('Выберите текст'));
  });
  test(
    'внешнее Писание: срезы, повторное использование главы и офлайн',
    () async {
      final f = fixture();
      final lines = (f['addresses.json'] as Map)['lines'] as List;
      lines[2]['body'] = {'absent': 'external'};
      lines[2]['address'] = 'bible:psaltir.1.2-3,1.1';
      lines[3]['address'] = 'bible:psaltir.1.1-2';
      final p = OrdoPackage.decode(pack(f));
      var calls = 0;
      await resolveOrdoScripture(
        p,
        loadChapter: (book, number) async {
          expect(book, 'psaltir');
          expect(number, 1);
          calls++;
          return BibleChapter.fromJson({
            'book': {'id': book},
            'chapter': number,
            'verses': [
              for (var i = 1; i <= 3; i++)
                {
                  'verse': i,
                  'editions': [
                    {'verse': i, 'content': 'Стих $i'},
                  ],
                },
            ],
          });
        },
      );
      expect(calls, 1);
      expect(texts(p), contains('Стих 2\nСтих 3 … Стих 1'));
      expect(texts(p), contains('Стих 1\nСтих 2'));
      final offline = OrdoPackage.decode(pack(fixture()));
      await resolveOrdoScripture(
        offline,
        loadChapter: (_, _) async => throw const SocketException('offline'),
      );
      expect(texts(offline).take(2), ['Текст второй', 'Текст первый']);
      expect(texts(offline), contains('bible:psaltir.1.1-2'));
    },
  );
  test('HTTP 503 означает недоступную серверную сборку', () async {
    await expectLater(
      getOrdoServices(
        DateTime(2026),
        fetch: (_) async => http.Response('', 503),
      ),
      throwsA(isA<ApiUnavailableException>()),
    );
  });
  test(
    'публичный .ordo без ключа и Cookie, бинарный кэш читается офлайн',
    () async {
      final dir = await Directory.systemTemp.createTemp('ordo-cache-test');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => dir.path);
      addTearDown(() async {
        // cachedFetch завершает запись асинхронно; ждём появления полноценной записи ниже.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await dir.delete(recursive: true);
      });
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/api/ordo/package');
        expect(request.headers.containsKey('authorization'), false);
        expect(request.headers.containsKey('cookie'), false);
        return http.Response.bytes(pack(fixture()), 200);
      });
      final date = DateTime(2026, 10, 25);
      final response = await fetchOrdoServices(date, client: client);
      expect(
        texts(OrdoPackage.decode(response.bodyBytes)).first,
        'Текст второй',
      );
      final cache = File(
        '${dir.path}/http_cache/ordo_package_v1_2026-10-25.json',
      );
      for (var i = 0; i < 100; i++) {
        if (await cache.exists() && await cache.length() > 0) {
          try {
            jsonDecode(await cache.readAsString());
            break;
          } catch (_) {}
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(await cache.exists(), true);
      final offline = await fetchOrdoServices(
        date,
        client: MockClient((_) async => throw Exception('offline')),
      );
      expect(
        OrdoPackage.decode(offline.bodyBytes).reading.services.single.title,
        'Утреня',
      );
      expect(calls, 1);
    },
  );
}
