import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/api/cached_fetch.dart';
import 'package:typikon/api/http_cache_version.dart';

class MemoryVersions implements HttpCacheVersionStorage {
  HttpCacheVersionState value = const HttpCacheVersionState();
  @override
  Future<HttpCacheVersionState> read() async => value;
  @override
  Future<void> write(HttpCacheVersionState state) async {
    value = state;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'metadata is public, old server falls back to health, malformed is ignored',
    () async {
      final paths = <String>[];
      final client = MockClient((r) async {
        expect(
          r.headers.keys.any(
            (h) => [
              'cookie',
              'authorization',
              'x-api-key',
            ].contains(h.toLowerCase()),
          ),
          false,
        );
        paths.add(r.url.path);
        return r.url.path.endsWith('cache-version')
            ? http.Response('', 404)
            : http.Response('{"buildId":"build-1"}', 200);
      });
      expect(
        await fetchHttpCacheServerVersion(client: client),
        'build:build-1',
      );
      expect(paths, ['/api/cache-version', '/api/health']);
      expect(
        await fetchHttpCacheServerVersion(
          client: MockClient((_) async => http.Response('{"version":{}}', 200)),
        ),
        null,
      );
      expect(
        await fetchHttpCacheServerVersion(
          client: MockClient((_) async => http.Response('', 503)),
        ),
        null,
      );
    },
  );

  test(
    'single flight, throttling, persisted revision and offline recovery',
    () async {
      final store = MemoryVersions();
      var time = DateTime(2026);
      var calls = 0;
      String? server = 'first';
      final v = HttpCacheVersions(
        storage: store,
        now: () => time,
        fetchServerVersion: () async {
          calls++;
          return server;
        },
      );
      addTearDown(v.dispose);
      final events = <void>[];
      final subscription = v.changes.listen(events.add);
      addTearDown(subscription.cancel);
      await Future.wait([v.check(), v.check(), v.check()]);
      expect(calls, 1);
      expect(events, isEmpty);
      final initial = v.generation;
      server = 'second';
      await v.check();
      expect(v.generation, initial);
      time = time.add(const Duration(minutes: 5));
      expect(await v.check(), true);
      await Future<void>.delayed(Duration.zero);
      expect(events.length, 1);
      final updated = v.generation;
      server = null;
      await v.check(force: true);
      expect(v.generation, updated);
      expect(v.serverReachable, false);
      expect(store.value.server, 'second');
      final reopened = HttpCacheVersions(
        storage: store,
        appBuild: 'new-app',
        fetchServerVersion: () async => null,
      );
      addTearDown(reopened.dispose);
      await reopened.check();
      expect(reopened.generation, contains('second'));
      expect(reopened.generation, isNot(updated));
    },
  );

  group('versioned HTTP cache', () {
    late Directory dir;
    late HttpCacheVersions v;
    late MemoryVersions storage;
    String? server;
    Future<http.Response> Function() response(
      String body, [
      int status = 200,
    ]) =>
        () async => http.Response(body, status);
    Future<void> seed({String body = 'saved', String? generation}) async {
      final cache = await Directory(
        '${dir.path}/http_cache',
      ).create(recursive: true);
      await File('${cache.path}/reading.json').writeAsString(
        jsonEncode({
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
          'body': body,
          'generation': ?generation,
        }),
      );
    }

    Future<Map<String, dynamic>> saved() async => jsonDecode(
      await File('${dir.path}/http_cache/reading.json').readAsString(),
    );

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('versioned-http-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path,
          );
      server = 'server-1';
      storage = MemoryVersions();
      v = HttpCacheVersions(
        storage: storage,
        appBuild: 'app-1',
        fetchServerVersion: () async => server,
      );
      await v.check();
    });
    tearDown(() async {
      await v.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      await dir.delete(recursive: true);
    });

    test(
      'legacy entry refreshes before returning and fresh entry is reused',
      () async {
        await seed();
        expect(
          (await cachedFetch('reading', response('new'), versions: v)).body,
          'new',
        );
        expect((await saved())['generation'], v.generation);
        expect(
          (await cachedFetch(
            'reading',
            () async => throw StateError('must use cache'),
            versions: v,
          )).body,
          'new',
        );
      },
    );

    test('server deployment refreshes even a long lived fresh entry', () async {
      await seed(generation: v.generation);
      server = 'server-2';
      await v.check(force: true);
      expect(
        (await cachedFetch(
          'reading',
          response('updated'),
          ttl: const Duration(days: 3650),
          versions: v,
        )).body,
        'updated',
      );
    });

    test('app upgrade refreshes cached entry', () async {
      await seed(generation: v.generation);
      final newer = HttpCacheVersions(
        storage: storage,
        appBuild: 'app-2',
        fetchServerVersion: () async => server,
      );
      addTearDown(newer.dispose);
      expect(
        (await cachedFetch(
          'reading',
          response('app-updated'),
          versions: newer,
        )).body,
        'app-updated',
      );
    });

    test(
      'offline and 5xx preserve old data without promoting its generation',
      () async {
        await seed();
        expect(
          (await cachedFetch('reading', response('', 503), versions: v)).body,
          'saved',
        );
        expect(
          (await cachedFetch(
            'reading',
            () async => throw const SocketException('offline'),
            versions: v,
          )).body,
          'saved',
        );
        expect((await saved()).containsKey('generation'), false);
        server = null;
        await v.check(force: true);
        expect(
          (await cachedFetch(
            'reading',
            () async => throw StateError('no request offline'),
            versions: v,
          )).body,
          'saved',
        );
      },
    );

    test('4xx is returned, invalid saved data is never used', () async {
      await seed();
      expect(
        (await cachedFetch(
          'reading',
          response('', 403),
          versions: v,
        )).statusCode,
        403,
      );
      expect(
        (await cachedFetch(
          'reading',
          response('valid'),
          isCacheable: (b) => b == 'valid',
          versions: v,
        )).body,
        'valid',
      );
    });

    test(
      'request begun before update cannot repopulate current cache',
      () async {
        final pending = Completer<http.Response>();
        final started = Completer<void>();
        final oldRequest = cachedFetch('reading', () {
          started.complete();
          return pending.future;
        }, versions: v);
        await started.future;
        server = 'server-2';
        await v.check(force: true);
        await cachedFetch('reading', response('current'), versions: v);
        pending.complete(http.Response('obsolete', 200));
        await oldRequest;
        expect((await saved())['body'], 'current');
      },
    );

    test(
      'manual clear invalidates in-flight writes and keeps personal preferences',
      () async {
        SharedPreferences.setMockInitialValues({
          'bookmark': 'place',
          'pomyannik': 'names',
          'theme': 'dark',
        });
        final pending = Completer<http.Response>();
        final started = Completer<void>();
        final request = cachedFetch('reading', () {
          started.complete();
          return pending.future;
        }, versions: v);
        await started.future;
        await clearHttpCache(versions: v);
        pending.complete(http.Response('old', 200));
        await request;
        expect(
          await File('${dir.path}/http_cache/reading.json').exists(),
          false,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('bookmark'), 'place');
        expect(prefs.getString('pomyannik'), 'names');
        expect(prefs.getString('theme'), 'dark');
      },
    );
  });

  test('revision storage touches only its own preference', () async {
    SharedPreferences.setMockInitialValues({
      'bookmark': 'keep',
      'pomyannik': 'keep',
      'theme': 'dark',
    });
    final store = PreferencesHttpCacheVersionStorage();
    await store.write(
      const HttpCacheVersionState(server: 'server-2', epoch: 3),
    );
    expect((await store.read()).epoch, 3);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), containsAll(['bookmark', 'pomyannik', 'theme']));
  });
}
