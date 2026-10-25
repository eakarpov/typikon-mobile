import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/api/prayer_text.dart' as api;
import 'package:typikon/apiMapper/prayer_text.dart';
import 'package:typikon/store/auth_token.dart';
import 'package:typikon/store/psalter_prayers.dart';
import 'package:typikon/store/pomyannik_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    readSessionCookie = () async => 'session-test';
  });
  tearDown(resetSessionCookieSource);
  test(
    'краткое поминовение загружается новым стилем и сохраняется для слав',
    () async {
      final styles = <String>[];
      final client = MockClient((request) async {
        expect(request.headers['Cookie'], 'session=session-test');
        expect(request.url.queryParameters['lang'], 'cu');
        final style = request.url.queryParameters['style']!;
        styles.add(style);
        final name = request.url.queryParameters['for'] == 'departed'
            ? 'Николая'
            : 'Марии';
        return http.Response(
          jsonEncode({
            'prayers': [
              {'id': style, 'text': 'Помяни $name'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final data = await loadPsalterNamedPrayers(
        gender: 'm',
        fetch: ({required forKind, required gender, style}) => getNamedPrayers(
          forKind: forKind,
          gender: gender,
          style: style,
          request: () => api.fetchPrayerText(
            forKind: forKind,
            gender: gender,
            style: style,
            client: client,
          ),
        ),
      );
      expect(styles, ['psalter-departed']);
      expect(data.departed.single.text, contains('Николая'));
      expect(data.living, isEmpty);
      final cached = await loadPsalterNamedPrayers(
        gender: 'm',
        fetch: ({required forKind, required gender, style}) async =>
            throw Exception('offline'),
      );
      expect(cached.departed.single.text, contains('Николая'));
      await clearPomyannikCache();
      expect(
        (await SharedPreferences.getInstance()).getString(
          'psalter_named_prayers',
        ),
        isNull,
      );
    },
  );
}
