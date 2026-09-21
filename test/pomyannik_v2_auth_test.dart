import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:typikon/api/v2/api_key.dart';
import 'package:typikon/api/v2/request.dart';
import 'package:typikon/store/auth_token.dart';

// Ключ и сессия — два разных отказа под одним кодом состояния, и спутать их
// стоит дороже всего остального в помяннике.
//
// Приложение по «401 на запрос с ключом» объявляет ключ негодным до
// перезапуска — глобально, а не в той ручке, где отказали. Сессия сайта живёт
// час. Значит, приняв протухшую сессию за плохой ключ, приложение убивало бы
// общий ключ по нескольку раз на дню, и не в помяннике, а в Библии, поиске и
// календаре, куда помянник и не заглядывает.
//
// Сервер называет причину сам: `unauthorized` и `forbidden` — про ключ,
// `session_required` — про вход.

http.Response json(String body, int status) =>
    http.Response(body, status, headers: {'content-type': 'application/json; charset=utf-8'});

http.Response denied(String code) => json('{"error":{"code":"$code","message":"нет"}}', 401);

void main() {
  setUp(() {
    resetApiKeyState();
    resetSessionCookieSource();
  });
  tearDown(() {
    resetApiKeyState();
    resetSessionCookieSource();
  });

  group('отказ ключу и отказ сессии', () {
    test('протухшая сессия ключа не роняет и повтора не вызывает', () async {
      readRawApiKey = () => 'tk_abcdef123456';
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return denied('session_required');
      });

      final response = await v2Get(v2Uri('/pomyannik/persons'), client: client);

      expect(calls, 1, reason: 'анонимом ходить в личный раздел незачем');
      expect(response.statusCode, 401);
      expect(apiKey, isNotNull, reason: 'ключ был исправен, метить его негодным нельзя');
    });

    test('непризнанный ключ по-прежнему признаётся негодным', () async {
      // Ради этого различие и заводилось: сузив проверку, легко разучиться
      // замечать настоящий отзыв.
      readRawApiKey = () => 'tk_abcdef123456';
      final client = MockClient((request) async =>
          request.headers.containsKey('Authorization') ? denied('unauthorized') : json('{}', 200));

      await v2Get(v2Uri('/bible/books'), client: client);

      expect(apiKey, isNull);
    });

    test('403 без раздела — тоже про ключ', () async {
      readRawApiKey = () => 'tk_abcdef123456';
      final client = MockClient((request) async => request.headers.containsKey('Authorization')
          ? json('{"error":{"code":"forbidden","message":"нет раздела"}}', 403)
          : json('{}', 200));

      await v2Get(v2Uri('/chants'), client: client);

      expect(apiKey, isNull);
    });

    test('отказ без разбираемого тела считается отказом ключу', () async {
      // Так вело себя приложение до появления личных разделов, и менять это на
      // «не трогать ключ» значило бы перестать замечать отзыв там, где ответ
      // пришёл не от нашего сервера — от прокси гостиничного Wi-Fi, например.
      readRawApiKey = () => 'tk_abcdef123456';
      final client = MockClient((request) async => request.headers.containsKey('Authorization')
          ? http.Response('<html>Unauthorized</html>', 401)
          : json('{}', 200));

      await v2Get(v2Uri('/bible/books'), client: client);

      expect(apiKey, isNull);
    });
  });

  group('личный запрос', () {
    test('несёт и ключ, и сессию — разными заголовками', () async {
      readRawApiKey = () => 'tk_abcdef123456';
      readSessionCookie = () async => 'печенье';
      final seen = <http.BaseRequest>[];
      final client = MockClient((request) async {
        seen.add(request);
        return json('{"items":[]}', 200);
      });

      await v2Send('GET', v2Uri('/pomyannik/persons'), client: client);

      expect(seen.single.headers['Authorization'], 'Bearer tk_abcdef123456');
      expect(seen.single.headers['Cookie'], 'session=печенье');
    });

    test('без входа идёт с одним ключом, а не падает', () async {
      // Отказать должен сервер, и своими словами: «нужен вход» — это его ответ,
      // а не наша догадка о том, что запрос бессмыслен.
      readRawApiKey = () => 'tk_abcdef123456';
      readSessionCookie = () async => null;
      final seen = <http.BaseRequest>[];
      final client = MockClient((request) async {
        seen.add(request);
        return denied('session_required');
      });

      await v2Send('GET', v2Uri('/pomyannik/persons'), client: client);

      expect(seen.single.headers.containsKey('Cookie'), isFalse);
      expect(apiKey, isNotNull);
    });

    test('на отказ не повторяется и ключ не метит — никогда', () async {
      // Даже на `unauthorized`: чинить сессию — дело withSession, а второй
      // запрос отсюда только съел бы попытку.
      readRawApiKey = () => 'tk_abcdef123456';
      readSessionCookie = () async => 'печенье';
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return denied('unauthorized');
      });

      await v2Send('PUT', v2Uri('/pomyannik/persons/1'), body: {'name': 'Анна'}, client: client);

      expect(calls, 1);
      expect(apiKey, isNotNull);
    });

    test('тело уходит кириллицей, а не в вопросительных знаках', () async {
      // Имена в помяннике русские все до одного: сорвись кодировка — сорвётся
      // весь раздел, и заметить это на латинице невозможно.
      readSessionCookie = () async => 'печенье';
      final bodies = <List<int>>[];
      final methods = <String>[];
      final client = MockClient((request) async {
        methods.add(request.method);
        bodies.add(request.bodyBytes);
        return json('{"items":[]}', 201);
      });

      await v2Send('POST', v2Uri('/pomyannik/persons'),
          body: {'name': 'Заха́рия', 'kind': 'departed'}, client: client);

      expect(methods.single, 'POST');
      final sent = jsonDecode(utf8.decode(bodies.single));
      expect(sent['name'], 'Заха́рия');
      expect(sent['kind'], 'departed');
    });

    test('запрос без тела заголовка о теле не ставит', () async {
      readSessionCookie = () async => 'печенье';
      final seen = <http.BaseRequest>[];
      final client = MockClient((request) async {
        seen.add(request);
        return json('{"deleted":true}', 200);
      });

      await v2Send('DELETE', v2Uri('/pomyannik/persons/1'), client: client);

      expect(seen.single.headers.containsKey('Content-Type'), isFalse);
    });
  });
}
