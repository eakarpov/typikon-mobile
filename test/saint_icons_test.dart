import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/api/dneslov/images.dart';
import 'package:typikon/apiMapper/saints.dart';
import 'package:typikon/components/saint_icons.dart';
import 'package:typikon/dto/saint.dart';
import 'package:typikon/dto/dneslov/images.dart';
import 'package:typikon/pages/saint_page.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';

final images = DneslovImageListD.fromJson([
  {
    'url': '/icons/full.webp',
    'thumb_url': '/icons/preview.webp',
    'title': 'Святой',
    'type': null,
    'uid': 1,
  },
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'normalizes CDN images, deduplicates, handles null fields and rejects other hosts',
    () {
      final list = DneslovImageListD.fromJson([
        {'url': 'http://cdn.dneslov.org/icons/a.webp'},
        {'url': '/icons/a.webp', 'thumbUrl': '/thumbs/a.webp'},
        {'url': 'https://example.com/track.png'},
        {'url': null},
      ]);
      expect(list.list.length, 1);
      expect(list.list.single.url, 'https://cdn.dneslov.org/icons/a.webp');
      expect(list.list.single.thumb_url, list.list.single.url);
      expect(
        dneslovImageUrl('//cdn.dneslov.org/icons/b.webp'),
        'https://cdn.dneslov.org/icons/b.webp',
      );
      expect(images.list.single.uid, '1');
    },
  );

  test('first empty memo cannot hide a later life', () {
    final life = SaintLife.fromJson({
      'slug': 'x',
      'memoes': [
        {'title': 'Заголовок'},
        {'title': 'Святой', 'description': 'Житие'},
      ],
    });
    expect(life.hasText, true);
    expect(life.memo?.description, 'Житие');
  });

  test(
    'saved images remain available when upstream fails and all external ids are preserved',
    () async {
      final saint = SaintDossier.fromJson({
        'name': 'Святой',
        'images': [
          {'url': '/icons/full.webp', 'thumbUrl': '/thumbs/full.webp'},
        ],
        'externals': [
          {'source': 'dneslov', 'id': 7974},
          {'source': 'dneslov', 'id': 7975},
        ],
      });
      expect(saint.dneslovIds, ['7974', '7975']);
      final result = await getSaintIcons(
        saint,
        fetch: (_) async => throw const SocketException('offline'),
      );
      expect(
        result.list.single.thumb_url,
        'https://cdn.dneslov.org/thumbs/full.webp',
      );
    },
  );

  test(
    'another memory can supply icons when one fails; all failures remain retryable',
    () async {
      const saint = SaintDossier(name: 'Святой', dneslovIds: ['1', '2']);
      final calls = <String>[];
      final result = await getSaintIcons(
        saint,
        fetch: (id) async {
          calls.add(id);
          if (id == '1') throw const SocketException('offline');
          return images;
        },
      );
      expect(calls, ['1', '2']);
      expect(result.list.length, 1);
      await expectLater(
        getSaintIcons(
          saint,
          fetch: (_) async => throw const SocketException('offline'),
        ),
        throwsA(isA<SocketException>()),
      );
    },
  );

  test('204 and 206 image responses are successful and cached', () async {
    final dir = await Directory.systemTemp.createTemp('saint-icons-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await dir.delete(recursive: true);
    });
    var calls = 0;
    final client = MockClient((r) async {
      calls++;
      return r.url.queryParameters['m'] == 'empty'
          ? http.Response('', 204)
          : http.Response(
              jsonEncode([
                {'url': '/icons/full.webp'},
              ]),
              206,
            );
    });
    for (final id in ['empty', 'full']) {
      final a = await fetchDneslovImages(id, client: client);
      final b = await fetchDneslovImages(id, client: client);
      expect(a.statusCode, 200);
      expect(b.body, a.body);
      expect(
        DneslovImageListD.fromJson(jsonDecode(a.body)).list.length,
        id == 'empty' ? 0 : 1,
      );
    }
    expect(calls, 2);
  });

  Future<void> imageCache() async {
    final dir = await Directory.systemTemp.createTemp('icon-pages-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await dir.delete(recursive: true);
    });
  }

  test(
    'loads all image records and counts body length rather than advertised end index',
    () async {
      await imageCache();
      final ranges = <String>[];
      final client = MockClient((r) async {
        final range = r.headers['range'] ?? r.headers['Range']!;
        ranges.add(range);
        final offset = int.parse(
          RegExp(r'records=(\d+)-').firstMatch(range)![1]!,
        );
        final count = offset == 0 ? 10 : 3;
        return http.Response(
          jsonEncode(
            List.generate(count, (i) => {'url': '/icons/${offset + i}.webp'}),
          ),
          206,
          headers: {
            'content-range': 'records $offset-${offset == 0 ? 9 : 109}/13',
          },
        );
      });
      final result = await fetchDneslovImages('all-pages', client: client);
      expect(
        DneslovImageListD.fromJson(jsonDecode(result.body)).list.length,
        13,
      );
      expect(ranges, ['records=0-100', 'records=10-110']);
      await fetchDneslovImages('all-pages', client: client);
      expect(ranges.length, 2);
    },
  );

  test('a repeated first page is not cached as a complete icon list', () async {
    await imageCache();
    final bad = MockClient(
      (_) async => http.Response(
        jsonEncode(List.generate(10, (i) => {'url': '/icons/$i.webp'})),
        206,
        headers: {'content-range': 'records 0-9/13'},
      ),
    );
    await expectLater(
      fetchDneslovImages('incomplete-pages', client: bad),
      throwsFormatException,
    );
    var calls = 0;
    final good = MockClient((_) async {
      calls++;
      return http.Response(
        jsonEncode([
          {'url': '/icons/fresh.webp'},
        ]),
        200,
      );
    });
    final response = await fetchDneslovImages('incomplete-pages', client: good);
    expect(calls, 1);
    expect(
      DneslovImageListD.fromJson(jsonDecode(response.body)).list.single.url,
      contains('fresh.webp'),
    );
  });

  testWidgets(
    'saint icons load in their own tab and open a zoomable full image',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        StoreProvider<AppState>(
          store: Store<AppState>(appReducer, initialState: AppState.init()),
          child: MaterialApp(
            home: SaintPage(
              null,
              id: 'saint',
              loadDossier: (_) async => const SaintDossier(name: 'Святой'),
              loadLife: (_) async => const SaintLife(
                slug: 'saint',
                memoes: [SaintLifeMemo(title: 'Святой', description: 'Житие')],
              ),
              loadIcons: (_) async {
                calls++;
                return images;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Иконы'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(SaintIcons), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('saint-icon-1')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      final urls = tester
          .widgetList<Image>(find.byType(Image))
          .map((w) => w.image)
          .whereType<NetworkImage>()
          .map((p) => p.url);
      expect(urls, contains('https://cdn.dneslov.org/icons/full.webp'));
    },
  );

  testWidgets(
    'failed icon lookup can be retried and empty result is explicit',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaintIcons(
              saint: const SaintDossier(name: 'Святой'),
              loader: (_) async {
                if (attempts++ == 0) throw const SocketException('offline');
                return const DneslovImageListD(list: []);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(
        find.text('Для этой записи пока нет изображений.'),
        findsOneWidget,
      );
      expect(attempts, 2);
    },
  );
}
