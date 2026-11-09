import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/components/companion_notes.dart';
import 'package:typikon/domain/companion.dart';
import 'package:typikon/store/companion.dart';

class NotesRepository extends CompanionRepository {
  NotesRepository(super.userId) : super(owner: () => userId);
  final writes = <CompanionJson>[];
  bool fail = false;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    CompanionJson? body,
    bool personal = false,
  }) async {
    if (method == 'GET') return {'userId': userId, 'notes': []};
    writes.add(companionCopy(body!));
    if (fail) throw Exception('Нет сети');
    return {
      'userId': userId,
      'note': {
        ...body,
        'revision': (body['expectedRevision'] as int) + 1,
        'shareToken': body['published'] == true ? 'a' * 48 : null,
      },
    };
  }
}

void main() {
  Future<void> open(WidgetTester tester, NotesRepository repo) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CompanionNotes(
              repository: repo,
              service: const {'sessionKey': 'vespers:date', 'title': 'Вечерня'},
              node: const {
                'id': 'ectenia-2',
                'contentHash': 'hash-2',
                'title': 'Ектения',
              },
              selection: const {
                'mode': 'day',
                'date': '2026-11-09',
                'service': 'vespers',
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Мои заметки к этому месту'));
    await tester.pumpAndSettle();
  }

  testWidgets('заметка приватна, публикация явная, отключение убирает ссылку', (
    tester,
  ) async {
    final repo = NotesRepository('alice');
    await open(tester, repo);
    await tester.enterText(find.byType(TextField), 'Важная мысль');
    await tester.tap(find.text('Сохранить приватно'));
    await tester.pumpAndSettle();
    expect(repo.writes.single['published'], false);
    expect(repo.writes.single['nodeId'], 'ectenia-2');
    expect(find.text('Скопировать ссылку'), findsNothing);

    await tester.tap(find.text('Опубликовать по ссылке'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(repo.writes.length, 1);
    await tester.tap(find.text('Опубликовать по ссылке'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Опубликовать'));
    await tester.pumpAndSettle();
    expect(repo.writes.last['published'], true);
    expect(repo.writes.last['expectedRevision'], 1);
    expect(find.text('Поделиться'), findsOneWidget);
    await tester.tap(find.text('Отключить доступ по ссылке'));
    await tester.pumpAndSettle();
    expect(repo.writes.last['published'], false);
    expect(find.text('Скопировать ссылку'), findsNothing);
  });

  testWidgets('сбой сохраняет текст и идентификатор для повтора отправки', (
    tester,
  ) async {
    final repo = NotesRepository('alice')..fail = true;
    await open(tester, repo);
    await tester.enterText(find.byType(TextField), 'Не потерять');
    await tester.tap(find.text('Сохранить приватно'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Не потерять',
    );
    repo.fail = false;
    await tester.tap(find.text('Сохранить приватно'));
    await tester.pumpAndSettle();
    expect(repo.writes[0]['id'], repo.writes[1]['id']);
  });

  testWidgets('гость видит предложение войти, личные запросы не отправляются', (
    tester,
  ) async {
    final repo = NotesRepository(null);
    await open(tester, repo);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(repo.writes, isEmpty);
  });
}
