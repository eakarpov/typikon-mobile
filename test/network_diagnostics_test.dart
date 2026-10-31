import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:typikon/api/cached_fetch.dart';
import 'package:typikon/utils/network_diagnostics.dart';
import 'package:typikon/pages/network_diagnostics_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('network-diagnostic-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await dir.delete(recursive: true);
  });

  test(
    'cache self-test exercises disk, upgrades and failures without touching existing data',
    () async {
      final cache = await Directory('${dir.path}/http_cache').create();
      final existing = File('${cache.path}/library.json');
      final original = jsonEncode({
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'body': '{"books":[]}',
        'generation': 'old-release',
      });
      await existing.writeAsString(original);
      final results = await testDiagnosticCache();
      expect(results, hasLength(5));
      expect(results.every((s) => s.startsWith('OK:')), isTrue);
      expect(await existing.readAsString(), original);
      expect(
        await cache.list().length,
        1,
        reason: 'temporary record must be removed',
      );
    },
  );

  test(
    'self-test detects a cache that cannot persist instead of claiming success',
    () async {
      await File(
        '${dir.path}/http_cache',
      ).writeAsString('directory is blocked');
      await expectLater(testDiagnosticCache(), throwsA(anything));
    },
  );

  test(
    'read-only inspection distinguishes missing, corrupt and valid entries',
    () async {
      expect(await inspectHttpCacheEntry('library'), {'exists': false});
      final file = File('${dir.path}/http_cache/library.json');
      await file.writeAsString('broken');
      expect(await inspectHttpCacheEntry('library'), {
        'exists': true,
        'readable': false,
      });
      final source = jsonEncode({
        'cachedAt': 1,
        'body': '{"private-sentinel": "do not include"}',
        'generation': 'old',
      });
      await file.writeAsString(source);
      final summary = await inspectHttpCacheEntry('library');
      expect(summary['jsonValid'], isTrue);
      expect(summary['currentGeneration'], isFalse);
      expect(jsonEncode(summary), isNot(contains('private-sentinel')));
      expect(await file.readAsString(), source);
    },
  );

  test('cleanup cannot remove a normal cache record', () async {
    await expectLater(
      removeDiagnosticCacheEntry('library'),
      throwsArgumentError,
    );
  });

  test(
    'native HTTPS result distinguishes success, TLS failure and HTTP failure',
    () async {
      const native = MethodChannel('su.typikon.typikon/utils');
      Object? report = {'status': 200, 'cipher': 'TLS_TEST'};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(native, (call) async {
            expect(call.method, 'diagnoseHttps');
            return report;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(native, null),
      );
      expect(await diagnoseAndroidHttps(), contains('Android HTTP 200'));
      report = {'error': 'SSLHandshakeException: test failure'};
      await expectLater(diagnoseAndroidHttps(), throwsA(isA<StateError>()));
      report = {'status': 503, 'cipher': 'TLS_TEST'};
      await expectLater(diagnoseAndroidHttps(), throwsA(isA<HttpException>()));
      report = null;
      await expectLater(diagnoseAndroidHttps(), throwsFormatException);
    },
  );

  test(
    'diagnostic bypass reads from network without changing existing cache',
    () async {
      if (!networkDiagnosticsEnabled) return;
      final cache = await Directory('${dir.path}/http_cache').create();
      final file = File('${cache.path}/library.json');
      await file.writeAsString('original saved bytes');
      bypassHttpCacheForDiagnostics = true;
      try {
        final response = await cachedFetch(
          'library',
          () async => http.Response('fresh network', 200),
        );
        expect(response.body, 'fresh network');
        expect(await file.readAsString(), 'original saved bytes');
        // The isolated self-test still exercises disk even when bypass is on.
        expect(await testDiagnosticCache(), hasLength(5));
      } finally {
        bypassHttpCacheForDiagnostics = false;
      }
    },
  );

  testWidgets('cache bypass is usable on a narrow diagnostic screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => bypassHttpCacheForDiagnostics = false);
    await tester.pumpWidget(const MaterialApp(home: NetworkDiagnosticsPage()));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(bypassHttpCacheForDiagnostics, isTrue);
    await tester.scrollUntilVisible(find.byType(FilledButton), 150);
    expect(find.text('Начать проверку'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
