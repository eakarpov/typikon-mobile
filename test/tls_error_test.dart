import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/components/api_error_view.dart';

/// Отказ проверки сертификата — не «нет интернета».
///
/// Так выглядела выкладка на typikon.info: сервер отдал свой сертификат без
/// промежуточного, и Android, который недостающее звено сам не дозагружает,
/// отказал разом всем страницам. Ошибка идёт мимо обёрток `http` — там ловятся
/// только SocketException и HttpException, — и до этой правки сводилась к
/// общему «не удалось загрузить».
void main() {
  final handshake = HandshakeException(
    "Handshake error in client",
    const OSError(
      "CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate",
    ),
  );

  test("отказ сертификата опознаётся", () {
    expect(isTlsError(handshake), isTrue);
    // И через строку: обёртки могут довезти его уже текстом.
    expect(isTlsError("$handshake"), isTrue);
  });

  test("обрыв сети за него не считается", () {
    expect(isTlsError(const SocketException("Failed host lookup")), isFalse);
    expect(isNetworkError(const SocketException("Failed host lookup")), isTrue);
  });

  testWidgets("человеку говорят, что дело не в его связи", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ApiErrorView(error: handshake, message: "Не удалось загрузить."),
      ),
    ));

    expect(find.textContaining("защищённое соединение"), findsOneWidget);
    expect(find.textContaining("на стороне сервера"), findsOneWidget);
    // Не «нет интернета»: связь есть, и чинить человеку нечего.
    expect(find.textContaining("Нет соединения"), findsNothing);
  });

  test("короткое сообщение о неудавшейся записи тоже не врёт про сеть", () {
    expect(failureMessage(handshake, "имя не записано"),
        "Сервер не отвечает как надо: имя не записано");
  });
}
