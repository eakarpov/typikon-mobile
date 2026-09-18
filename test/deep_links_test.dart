import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/api/constants.dart';

// Ссылки сайта, открываемые приложением. Разъезд здесь молчалив вдвойне: хост
// живёт в манифесте, а домен — в constants.dart, и сменив второй, о первом легко
// не вспомнить. Ссылка тогда просто уходит в браузер — ни ошибки, ни жалобы.

String _manifest() =>
    File("android/app/src/main/AndroidManifest.xml").readAsStringSync();

/// Хосты из фильтра, который система сверяет с /.well-known/assetlinks.json.
Set<String> _verifiedHosts(String manifest) {
  final block = RegExp(
    r'<intent-filter android:autoVerify="true">(.*?)</intent-filter>',
    dotAll: true,
  ).firstMatch(manifest);

  expect(block, isNotNull, reason: "в манифесте нет заверяемого фильтра ссылок");

  return RegExp(r'android:host="([^"]+)"')
      .allMatches(block!.group(1)!)
      .map((m) => m.group(1)!)
      .toSet();
}

void main() {
  test("домен, на который ходит приложение, заверен как свой", () {
    // Иначе ссылка с сайта откроется в браузере, а не в приложении.
    expect(_verifiedHosts(_manifest()), contains(siteHostFull));
  });

  test("заверены все домены, которые считаем своими", () {
    // ownHosts переживает переезд с нахлёстом: ссылки со старого домена розданы
    // и ходят по рукам, пока он отвечает.
    final verified = _verifiedHosts(_manifest());

    for (final host in ownHosts) {
      expect(verified, contains("www.$host"),
          reason: "ссылки с $host перестанут открываться в приложении");
    }
  });

  test("заверяются только те формы, что отвечают без редиректа", () {
    // Проверка отпечатка редиректов не допускает, а голый домен отвечает на
    // /.well-known/ перенаправлением на www. До Android 11 включительно одна
    // незаверенная строка роняет проверку всех остальных разом.
    for (final host in _verifiedHosts(_manifest())) {
      expect(host, startsWith("www."),
          reason: "$host отвечает редиректом, и проверка на нём не пройдёт");
    }
  });

  test("в заверяемом фильтре только http и https", () {
    // Собственные схемы в нём запрещены: фильтр со схемой app не заверяется
    // вовсе, и вместе с ним перестают заверяться ссылки сайта.
    final block = RegExp(
      r'<intent-filter android:autoVerify="true">(.*?)</intent-filter>',
      dotAll: true,
    ).firstMatch(_manifest())!;

    final schemes = RegExp(r'android:scheme="([^"]+)"')
        .allMatches(block.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();

    expect(schemes, {"http", "https"});
  });
}
