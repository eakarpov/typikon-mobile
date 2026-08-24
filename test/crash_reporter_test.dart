import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/utils/crash_reporter.dart';

void main() {
  setUp(resetCrashReporterState);

  group("тело отчёта", () {
    test("содержит тип, сообщение и стек", () {
      final payload = buildClientErrorPayload(
        error: StateError("что-то пошло не так"),
        stack: StackTrace.fromString("#0 someFrame (file.dart:1)"),
        context: "building TextPage",
        platform: "android",
        version: "1.5.0+6",
      );

      expect(payload["name"], "StateError");
      expect(payload["message"], contains("что-то пошло не так"));
      expect(payload["stack"], contains("someFrame"));
    });

    test("where собирает место, платформу и версию", () {
      final payload = buildClientErrorPayload(
        error: Exception("x"),
        context: "building TextPage",
        platform: "android",
        version: "1.5.0+6",
      );

      expect(payload["where"], "building TextPage · android · 1.5.0+6");
    });

    test("без места где-то всё равно остаётся платформа и версия", () {
      final payload = buildClientErrorPayload(
        error: Exception("x"),
        context: "   ",
        platform: "ios",
        version: "1.5.0+6",
      );

      expect(payload["where"], "ios · 1.5.0+6");
    });

    test("отсутствующий стек не превращается в null", () {
      final payload = buildClientErrorPayload(error: Exception("x"), platform: "android", version: "1");

      expect(payload["stack"], "");
    });

    test("в отчёте только четыре технических поля", () {
      final payload = buildClientErrorPayload(error: Exception("x"), platform: "android", version: "1");

      expect(payload.keys.toSet(), {"name", "message", "stack", "where"});
    });
  });

  group("подпись ошибки", () {
    test("одинаковый сбой даёт одинаковую подпись", () {
      final stack = StackTrace.fromString("#0 build (text_page.dart:42)");

      expect(
        crashSignature(StateError("одно"), stack),
        crashSignature(StateError("одно"), stack),
      );
    });

    test("разное место — разная подпись", () {
      expect(
        crashSignature(StateError("одно"), StackTrace.fromString("#0 a (a.dart:1)")),
        isNot(crashSignature(StateError("одно"), StackTrace.fromString("#0 b (b.dart:1)"))),
      );
    });

    test("разное сообщение — разная подпись", () {
      final stack = StackTrace.fromString("#0 a (a.dart:1)");

      expect(
        crashSignature(StateError("одно"), stack),
        isNot(crashSignature(StateError("другое"), stack)),
      );
    });
  });

  test("в отладочной сборке ничего не отправляется", () async {
    // Тесты идут в debug-режиме, поэтому reportCrash обязан промолчать —
    // иначе прогон тестов начал бы стучаться в прод.
    await reportCrash(StateError("тест"), StackTrace.current);

    expect(crashReportsSent, 0);
  });
}
