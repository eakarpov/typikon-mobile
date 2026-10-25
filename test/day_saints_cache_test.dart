import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:typikon/api/calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'старый многолетний снимок не используется, неполный ответ не кэшируется',
    () async {
      final dir = await Directory.systemTemp.createTemp('day-saints-cache-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => dir.path);
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await dir.delete(recursive: true);
      });
      const date = '2020-01-01';
      final cacheDir = await Directory('${dir.path}/http_cache').create();
      await File('${cacheDir.path}/saints-day_2020-01-01.json').writeAsString(
        jsonEncode({
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
          'body': '{"saints":[]}',
        }),
      );
      var calls = 0;
      final client = MockClient((r) async {
        calls++;
        expect(r.url.path, '/api/v2/calendar/$date/saints');
        return http.Response(
          '{"date":"$date","saints":[],"partial":true}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final first = await fetchDaySaints(date, client: client);
      await fetchDaySaints(date, client: client);
      expect(jsonDecode(first.body)['partial'], true);
      expect(calls, 2);
      expect(
        await File('${cacheDir.path}/saints-day_v2_2020-01-01.json').exists(),
        false,
      );
    },
  );
}
