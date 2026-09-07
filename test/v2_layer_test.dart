import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:typikon/api/cached_fetch.dart';
import 'package:typikon/api/constants.dart';
import 'package:typikon/api/v2/api_key.dart';
import 'package:typikon/api/v2/request.dart';
import 'package:typikon/apiMapper/v2/errors.dart';

// Слой второй версии API. Три места, где ошибка не видна глазами и потому
// обязана быть поймана тестом: приставка ключа (сервер молча откатит в анонимы),
// отказ ключа (раздел должен продолжить работать, а не погаснуть) и то, что
// кладётся в кэш (поломка, положенная на диск, живёт весь TTL).

// http.Response без content-type кодирует тело в Latin-1 и падает на кириллице —
// та же ловушка, из-за которой cached_fetch пересобирает кэшированный ответ с
// явной кодировкой. Русские сообщения сервера строим только через это.
http.Response json(String body, int status, {Map<String, String> headers = const {}}) =>
    http.Response(body, status, headers: {
      'content-type': 'application/json; charset=utf-8',
      ...headers,
    });

void main() {
  setUp(resetApiKeyState);
  tearDown(resetApiKeyState);

  group('ключ', () {
    test('годный ключ признаётся', () {
      expect(normalizeApiKey('tk_abcdef123456'), 'tk_abcdef123456');
    });

    test('пробелы по краям срезаются', () {
      // Значение приезжает из .env, где пробел в конце строки не виден.
      expect(normalizeApiKey('  tk_abcdef123456\n'), 'tk_abcdef123456');
    });

    test('значение без приставки ключом не считается', () {
      // Сервер на такое не ругается, а молча считает клиента анонимом: опечатка
      // в .env обернулась бы не ошибкой, а 60 запросами в час.
      expect(normalizeApiKey('abcdef123456'), isNull);
    });

    test('одна приставка без ключа не считается ключом', () {
      expect(normalizeApiKey('tk_'), isNull);
    });

    test('пустое и отсутствующее значение — не ключ', () {
      expect(normalizeApiKey(''), isNull);
      expect(normalizeApiKey('   '), isNull);
      expect(normalizeApiKey(null), isNull);
    });

    test('заголовок ставится только при годном ключе', () {
      readRawApiKey = () => 'tk_abcdef123456';
      expect(apiKeyHeaders(), {'Authorization': 'Bearer tk_abcdef123456'});

      readRawApiKey = () => 'мусор';
      expect(apiKeyHeaders(), isEmpty);
    });
  });

  group('запрос', () {
    test('адрес собирается из одного корня', () {
      expect(v2Uri('/bible/books').toString(), '$apiBaseUrl/api/v2/bible/books');
    });

    test('параметры кодируются, а не склеиваются строкой', () {
      // Коды изданий идут списком через запятую; ручная склейка однажды дала бы
      // пробел или незакодированный & внутри значения.
      final uri = v2Uri('/bible/matfeya/1', {'editions': 'cs-eliz,grc-lxx-pat'});

      expect(uri.queryParameters['editions'], 'cs-eliz,grc-lxx-pat');
      expect(uri.toString(), contains('editions=cs-eliz%2Cgrc-lxx-pat'));
    });

    test('запрос несёт ключ, когда он есть', () async {
      readRawApiKey = () => 'tk_abcdef123456';
      final seen = <http.BaseRequest>[];
      final client = MockClient((request) async {
        seen.add(request);
        return http.Response('{}', 200);
      });

      await v2Get(v2Uri('/bible/books'), client: client);

      expect(seen.single.headers['Authorization'], 'Bearer tk_abcdef123456');
    });

    test('непризнанный ключ не гасит раздел, а роняет нас в анонимы', () async {
      // Ключ один на все установленные копии: отзови его кто-нибудь по недосмотру
      // вместе с чужими — и раздел погас бы разом у всех до следующего выпуска.
      readRawApiKey = () => 'tk_abcdef123456';
      final seen = <http.BaseRequest>[];
      final client = MockClient((request) async {
        seen.add(request);
        return request.headers.containsKey('Authorization')
            ? json('{"error":{"code":"unauthorized","message":"Ключ не признан."}}', 401)
            : json('{"items":[]}', 200);
      });

      final response = await v2Get(v2Uri('/bible/books'), client: client);

      expect(response.statusCode, 200, reason: 'повтор без ключа должен был пройти');
      expect(seen.length, 2);
      expect(seen.first.headers.containsKey('Authorization'), isTrue);
      expect(seen.last.headers.containsKey('Authorization'), isFalse);
      expect(apiKey, isNull, reason: 'ключ должен считаться негодным до перезапуска');
    });

    test('следующий запрос после отказа ключа уже не пробует его снова', () async {
      readRawApiKey = () => 'tk_abcdef123456';
      var withKey = 0;
      final client = MockClient((request) async {
        if (request.headers.containsKey('Authorization')) {
          withKey++;
          return http.Response('{"error":{"code":"unauthorized"}}', 401);
        }
        return http.Response('{}', 200);
      });

      await v2Get(v2Uri('/bible/books'), client: client);
      await v2Get(v2Uri('/bible/editions'), client: client);

      expect(withKey, 1, reason: 'негодный ключ пробуется один раз, а не на каждом запросе');
    });

    test('там, где анониму не полагается вовсе, повтора нет', () async {
      // Поиск по песнопениям и зачинам живёт в разделе `search`, единственном
      // вне бесплатных. Повторять там нечего: второй запрос вернёт тот же 401,
      // зато ключ окажется помечен негодным из-за ручки, которая его отвергла
      // не потому, что он плох.
      readRawApiKey = () => 'tk_abcdef123456';
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return json('{"error":{"code":"unauthorized","message":"Доступно по ключу."}}', 401);
      });

      final response = await v2Get(v2Uri('/chants'), client: client, retryAnonymously: false);

      expect(calls, 1, reason: 'повтора быть не должно');
      expect(response.statusCode, 401);
      expect(apiKey, isNotNull, reason: 'ключ ни при чём, метить его негодным нельзя');
    });

    test('обычная ошибка сервера повтором без ключа не лечится', () async {
      // 500 — не про ключ, и терять его, второй раз дёргая сервер, незачем.
      readRawApiKey = () => 'tk_abcdef123456';
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return json('{"error":{"code":"internal","message":"Не удалось"}}', 500);
      });

      final response = await v2Get(v2Uri('/bible/books'), client: client);

      expect(calls, 1);
      expect(response.statusCode, 500);
      expect(apiKey, isNotNull, reason: 'ключ ни при чём, метить его негодным нельзя');
    });
  });

  group('разбор отказа', () {
    http.Response error(int status, String code, String message, {Map<String, String>? headers}) =>
        json('{"error":{"code":"$code","message":"$message"}}', status, headers: headers ?? const {});

    test('код и сообщение берутся из тела', () {
      final response = error(404, 'not_found', 'Такой книги нет ни в каноне, ни в приложении');

      expect(v2ErrorCode(response), 'not_found');
      expect(v2ErrorMessage(response, 'запасное'), 'Такой книги нет ни в каноне, ни в приложении');
    });

    test('неразобравшееся тело не роняет разбор, а отдаёт запасное сообщение', () {
      final response = json('<html>502 Bad Gateway</html>', 502);

      expect(v2ErrorCode(response), isNull);
      expect(v2ErrorMessage(response, 'запасное'), 'запасное');
    });

    test('сообщение сервера показывается как есть, а не заменяется общим', () {
      // «В этих изданиях такой главы нет» — не ошибка приложения, а честный ответ
      // про Исход 37–39 или про Апокалипсис в китайском Новом Завете.
      final response = error(404, 'not_found', 'В этих изданиях такой главы нет');

      expect(
        () => throwV2Error(response, 'Не удалось загрузить главу'),
        throwsA(isA<ApiNotFoundException>()
            .having((e) => e.message, 'message', 'В этих изданиях такой главы нет')),
      );
    });

    test('слишком частые запросы — своё исключение со временем ожидания', () {
      final response = error(429, 'rate_limited', 'Слишком часто', headers: {'retry-after': '42'});

      expect(
        () => throwV2Error(response, 'Не удалось'),
        throwsA(isA<ApiRateLimitedException>()
            .having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 42))
            .having((e) => e.message, 'message', contains('42'))),
      );
    });

    test('без Retry-After обходимся без числа, а не выдумываем его', () {
      final response = error(429, 'rate_limited', 'Слишком часто');

      expect(
        () => throwV2Error(response, 'Не удалось'),
        throwsA(isA<ApiRateLimitedException>()
            .having((e) => e.retryAfter, 'retryAfter', isNull)
            .having((e) => e.message, 'message', isNot(contains('через')))),
      );
    });

    test('отказ по ключу несёт сообщение сервера, а не общее', () {
      // «Этот раздел доступен по ключу» точнее нашего «не удалось выполнить
      // поиск» — и говорит правду: поиск не сломался, его просто не дали.
      final response = error(401, 'unauthorized', 'Этот раздел доступен по ключу.');

      expect(
        () => throwV2Error(response, 'Не удалось выполнить поиск'),
        throwsA(isA<ApiUnauthorizedException>()
            .having((e) => e.message, 'message', 'Этот раздел доступен по ключу.')),
      );
    });

    test('без ключа к отказу по частоте добавляется объяснение', () {
      // Иначе читатель на приходском Wi-Fi решит, что это он торопится.
      readRawApiKey = () => null;
      final response = error(429, 'rate_limited', 'Слишком часто');

      expect(
        () => throwV2Error(response, 'Не удалось'),
        throwsA(isA<ApiRateLimitedException>()
            .having((e) => e.anonymous, 'anonymous', isTrue)
            .having((e) => e.hint, 'hint', contains('60 запросов'))),
      );
    });

    test('с ключом лишнего про адрес сети не говорим', () {
      readRawApiKey = () => 'tk_abcdef123456';
      final response = error(429, 'rate_limited', 'Слишком часто');

      expect(
        () => throwV2Error(response, 'Не удалось'),
        throwsA(isA<ApiRateLimitedException>()
            .having((e) => e.anonymous, 'anonymous', isFalse)
            .having((e) => e.hint, 'hint', isNull)),
      );
    });
  });

  group('что кладётся в кэш', () {
    test('без проверки годен всякий ответ 200 — как было', () {
      expect(isResponseCacheable(http.Response('{}', 200), null), isTrue);
    });

    test('не-200 не кэшируется', () {
      expect(isResponseCacheable(http.Response('{}', 404), null), isFalse);
    });

    test('пустое тело под кодом 200 на диск не ложится', () {
      // Ровно этот случай и растянул поломку: веб убрал прежнюю модель Библии, и
      // /api/v1/texts/{id} на исчезнувший текст стал отвечать 200 с пустым телом.
      // Ответ ложился в кэш, и ошибка жила там весь TTL.
      expect(isResponseCacheable(http.Response('', 200), _isJsonObject), isFalse);
      expect(isResponseCacheable(http.Response('{"items":[]}', 200), _isJsonObject), isTrue);
    });

    test('упавшая проверка означает «не кэшировать», а не падение вызова', () {
      expect(
        isResponseCacheable(json('что угодно', 200), (_) => throw StateError('бум')),
        isFalse,
      );
    });
  });
}

/// Проверка вида той, что подставит раздел Библии: тело обязано быть json-объектом.
bool _isJsonObject(String body) => jsonDecode(body) is Map;
