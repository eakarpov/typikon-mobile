import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:typikon/apiMapper/ordo.dart';
import 'package:typikon/api/cached_fetch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redux/redux.dart';
import 'package:typikon/dto/ordo_services.dart';
import 'package:typikon/pages/ordo_page.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/rootReducer.dart';
import 'package:typikon/apiMapper/v2/errors.dart';
import 'package:typikon/utils/day_preloader.dart';
import 'package:typikon/components/continue_reading.dart';

void main() {
  test('маппер различает отказ ключа, квоту и повреждённый ответ', () async {
    final date = DateTime(2026, 10, 18);
    for (final code in [401, 403]) {
      await expectLater(
        getOrdoServices(date, fetch: (_) async => http.Response('', code)),
        throwsA(
          isA<ApiUnauthorizedException>().having(
            (e) => e.message,
            'message',
            contains('Обновите'),
          ),
        ),
      );
    }
    await expectLater(
      getOrdoServices(date, fetch: (_) async => http.Response('', 429)),
      throwsA(isA<ApiRateLimitedException>()),
    );
    await expectLater(
      getOrdoServices(date, fetch: (_) async => http.Response('{}', 200)),
      throwsFormatException,
    );
    final json = jsonEncode({
      'services': [
        {'label': 'Утреня', 'steps': []},
      ],
    });
    final data = await getOrdoServices(
      date,
      fetch: (_) async => http.Response(
        json,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    expect(data.services.single.title, 'Утреня');
    expect(isResponseCacheable(http.Response('', 403), (_) => true), isFalse);
  });

  test('линейные тексты сохраняют порядок, повторы и вложенные шаги', () {
    final data = OrdoServices.fromJson({
      'services': [
        {
          'label': 'Утреня',
          'steps': [
            {'kind': 'include', 'label': 'Канон'},
            {
              'kind': 'position',
              'speaker': 'Хор',
              'items': [
                {'text': 'Тропарь'},
                {'text': 'Тропарь'},
                {
                  'is_nested_step': true,
                  'step': {'kind': 'text', 'text': 'Седален'},
                },
                {'text': 'Следующий тропарь'},
                {'absent': 'external'},
              ],
            },
          ],
        },
      ],
    });
    expect(data.services.single.sections.expand((s) => s.texts), [
      'Тропарь',
      'Тропарь',
      'Седален',
      'Следующий тропарь',
      'Текст Писания не включён в пакет.',
    ]);
    expect(data.services.single.sections.first.title, 'Канон');
    expect(() => OrdoServices.fromJson({}), throwsFormatException);
  });

  Future<void> pump(
    WidgetTester tester,
    Future<OrdoServices> Function(DateTime) loader,
  ) async {
    await tester.pumpWidget(
      StoreProvider<AppState>(
        store: Store<AppState>(appReducer, initialState: AppState.init()),
        child: MaterialApp(home: OrdoPage(loader: loader)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('служба дня: тексты по местам, без ролей', (tester) async {
    await pump(
      tester,
      (_) async => OrdoServices.fromJson({
        'services': [
          {
            'label': 'Вечерня',
            'steps': [
              {
                'kind': 'text',
                'label': 'Начало',
                'speaker': 'Иерей',
                'text': 'Благословен Бог',
              },
            ],
          },
        ],
      }),
    );
    expect(find.text('Вечерня'), findsOneWidget);
    expect(find.text('Начало'), findsOneWidget);
    expect(find.text('Благословен Бог'), findsOneWidget);
    expect(find.text('Иерей'), findsNothing);
  });
  testWidgets('отказ доступа предлагает обновление', (tester) async {
    await pump(
      tester,
      (_) async => throw const ApiUnauthorizedException(
        'Раздел «Служба дня» недоступен. Обновите приложение.',
      ),
    );
    expect(find.textContaining('Обновите приложение'), findsOneWidget);
  });
  testWidgets('пустой день обозначен явно', (tester) async {
    await pump(tester, (_) async => const OrdoServices([]));
    expect(find.text('На эту дату службы не собраны.'), findsOneWidget);
  });
  testWidgets('после ошибки загрузку можно повторить', (tester) async {
    var attempts = 0;
    await pump(tester, (_) async {
      if (++attempts == 1) throw Exception('Сбой');
      return const OrdoServices([OrdoService('Часы', [])]);
    });
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Часы'), findsOneWidget);
  });

  test(
    'предзагрузка: один запрос на дату, после сбоя можно повторить',
    () async {
      resetPreloaderState();
      final date = DateTime(2026, 10, 18);
      var calls = 0;
      Future<void> fail(DateTime _) async {
        calls++;
        throw Exception('нет сети');
      }

      await preloadOrdo(date, fetch: fail);
      final done = Completer<void>();
      Future<void> fetch(DateTime _) {
        calls++;
        return done.future;
      }

      final pending = preloadOrdo(date, fetch: fetch);
      await preloadOrdo(date, fetch: fetch);
      expect(calls, 2);
      done.complete();
      await pending;
      await preloadOrdo(date, fetch: fetch);
      expect(calls, 2);
    },
  );

  test('продолжение ведёт в соответствующий раздел', () {
    expect(
      continueReadingTarget('psalter:kathisma:17').name,
      '/psalter/kathisma',
    );
    expect(continueReadingTarget('psalter:kathisma:17').arguments, 17);
    expect(continueReadingTarget('psalter:psalm:151').arguments, 151);
    expect(continueReadingTarget('psalter:serial').name, '/psalter/serial');
    expect(continueReadingTarget('rule:2026-10-18').name, '/rule');
    expect(
      continueReadingTarget('communion:2026-10-19').arguments,
      '2026-10-19',
    );
    expect(continueReadingTarget('text-id').arguments, 'text-id');
  });
}
