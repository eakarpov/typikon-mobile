import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:typikon/apiMapper/session.dart';

/// Плагинов (secure storage, google_sign_in) в тестовой среде нет, поэтому
/// тихое продление сессии здесь всегда неуспешно — то есть проверяется именно
/// ветка "продлить не вышло".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("успешный ответ проходит насквозь, запрос уходит один раз", () async {
    var calls = 0;
    final response = await withSession(() async {
      calls++;
      return http.Response('[]', 200);
    });

    expect(calls, 1);
    expect(response.statusCode, 200);
  });

  test("не-401 не считается истёкшей сессией", () async {
    var calls = 0;
    final response = await withSession(() async {
      calls++;
      return http.Response('', 500);
    });

    expect(calls, 1);
    expect(response.statusCode, 500);
  });

  test("401 без возможности продлить — SessionExpiredException", () async {
    var calls = 0;

    expect(
      () => withSession(() async {
        calls++;
        return http.Response('', 401);
      }),
      throwsA(isA<SessionExpiredException>()),
    );

    await Future<void>.delayed(Duration.zero);
    expect(calls, 1, reason: "повторять запрос без новой сессии бессмысленно");
  });
}
