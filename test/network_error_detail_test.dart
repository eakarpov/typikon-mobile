import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/components/api_error_view.dart';
import 'package:typikon/utils/network_error_detail.dart';

/// Разбор причины сетевого отказа для разработчика.
///
/// Читателю сырое исключение не показывают нарочно (см. `failureMessage`), но на
/// MIUI одинаковое «нет соединения» прячет и сломанный DNS, и прокси, и
/// сертификат, и запрет доступа прошивкой. Различает их код `osError`, и потерять
/// его в разборе значило бы не отладить ровно тот случай, ради которого он
/// заведён.
void main() {
  const lookup = SocketException(
    "Failed host lookup",
    osError: OSError("No address associated with hostname", 7),
  );

  test("код osError виден в разборе", () {
    final said = describeNetworkError(lookup);
    expect(said, contains("SocketException"));
    expect(said, contains("osError 7"));
    expect(said, contains("Failed host lookup"));
  });

  test("у непонятной ошибки кода нет, но тип есть", () {
    final said = describeNetworkError(Exception("боль"));
    expect(said, contains("Exception"));
    expect(said, contains("боль"));
    expect(said, isNot(contains("osError")));
  });

  test("сертификат назван сертификатом, а не сетью", () {
    final handshake = HandshakeException(
      "Handshake error in client",
      const OSError("CERTIFICATE_VERIFY_FAILED", -1),
    );
    expect(describeNetworkError(handshake), contains("HandshakeException"));
    expect(describeNetworkError(handshake), contains("CERTIFICATE_VERIFY_FAILED"));
  });

  testWidgets("в отладке причина видна, а обычная ошибка — нет", (tester) async {
    // kDebugMode под flutter test истинно, так что это и есть отладочный экран.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ApiErrorView(error: lookup, message: "Не удалось загрузить."),
      ),
    ));
    // Читателю — то же доброе «нет соединения», что и раньше.
    expect(find.text("Нет соединения с интернетом."), findsOneWidget);
    // Разработчику — код, по которому причина и различается.
    expect(find.textContaining("osError 7"), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ApiErrorView(error: Exception("боль"), message: "Не удалось."),
      ),
    ));
    // Не сетевая — и сырого текста нет: он бы только пугал.
    expect(find.textContaining("боль"), findsNothing);
  });
}
