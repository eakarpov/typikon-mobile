import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:typikon/apiMapper/session.dart';
import 'package:typikon/apiMapper/auth.dart';

void main() {
  test('без сессии запрос не открывает Google и не запускает выход', () async {
    var refreshes = 0, exits = 0;
    for (var i = 0; i < 3; i++) {
      await expectLater(
        withSession(
          () async => http.Response('', 401),
          readCookie: () async => null,
          refresh: () async {
            refreshes++;
            return false;
          },
          forget: () async {
            exits++;
          },
        ),
        throwsA(isA<SessionExpiredException>()),
      );
    }
    expect(refreshes, 0);
    expect(exits, 0);
  });
  test('отказ API-ключа не обновляет Google и не стирает вход', () async {
    var refreshes = 0, exits = 0;
    final response = await withSession(
      () async => http.Response('{"error":{"code":"unauthorized"}}', 401),
      readCookie: () async => 'cookie',
      refresh: () async {
        refreshes++;
        return true;
      },
      forget: () async {
        exits++;
      },
    );
    expect(response.statusCode, 401);
    expect(refreshes, 0);
    expect(exits, 0);
  });
  test(
    'сессия обновляется лишь один раз; повторный отказ завершает запрос',
    () async {
      var calls = 0, refreshes = 0, exits = 0;
      await expectLater(
        withSession(
          () async {
            calls++;
            return http.Response('{"error":{"code":"session_required"}}', 401);
          },
          readCookie: () async => 'cookie',
          refresh: () async {
            refreshes++;
            return true;
          },
          forget: () async {
            exits++;
          },
        ),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(calls, 2);
      expect(refreshes, 1);
      expect(exits, 1);
    },
  );
  test(
    'параллельно обновлённая сессия переиспользуется без нового Google-входа',
    () async {
      var cookie = 'old';
      var calls = 0, refreshes = 0;
      final result = await withSession(
        () async {
          if (++calls == 1) {
            cookie = 'new';
            return http.Response('', 401);
          }
          return http.Response('ok', 200);
        },
        readCookie: () async => cookie,
        refresh: () async {
          refreshes++;
          return true;
        },
      );
      expect(result.statusCode, 200);
      expect(calls, 2);
      expect(refreshes, 0);
    },
  );
  test('session находится среди нескольких Set-Cookie', () {
    expect(
      extractSessionCookie('csrf=x; Path=/, session=token; HttpOnly'),
      'token',
    );
    expect(extractSessionCookie('session=token; Path=/'), 'token');
    expect(extractSessionCookie('session=; Path=/'), isNull);
    expect(extractSessionCookie('not_session=x'), isNull);
  });
}
