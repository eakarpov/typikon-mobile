import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/api/constants.dart';
import 'package:typikon/routes.dart';

// Ссылки сайта, открываемые приложением. Разъезд здесь молчалив втройне: хост
// живёт в манифесте, домен — в constants.dart, адреса ярлыков на иконке —
// в res/xml/shortcuts.xml, и сменив одно, о прочем легко не вспомнить. Ссылка
// тогда просто уходит в браузер — ни ошибки, ни жалобы.

String _manifest() =>
    File("android/app/src/main/AndroidManifest.xml").readAsStringSync();

String _shortcutsXml() =>
    File("android/app/src/main/res/xml/shortcuts.xml").readAsStringSync();

/// Адреса из ярлыков на иконке: система отдаёт их приложению тем же
/// VIEW-интентом, что и ссылки сайта, поэтому дальше их ждёт тот же deeplinking.
List<String> _shortcutLinks() => RegExp(r'android:data="([^"]+)"')
    .allMatches(_shortcutsXml())
    .map((m) => m.group(1)!)
    .toList();

/// Имя разрешается маршрутом БЕЗ аргумента. generateRoute отвечает null и на
/// незнакомое имя, и на маршрут, чей аргумент обязателен (так ярлык попал бы
/// на страницу «не найдено»), — ярлыку годится только разрешающееся голым.
bool _resolves(String name) => generateRoute(
      RouteSettings(name: name),
      hasSkippedUpdate: true,
      skipUpdateWindow: (_) {},
    ) !=
    null;

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

  group("ярлыки на иконке", () {
    test("манифест отдаёт список ярлыков лаунчеру", () {
      final manifest = _manifest();
      expect(manifest, contains('android:name="android.app.shortcuts"'));
      expect(manifest, contains('android:resource="@xml/shortcuts"'));
    });

    test("каждый ярлык ведёт в раздел, открывающийся без аргумента", () {
      final links = _shortcutLinks();
      expect(links, isNotEmpty,
          reason: "в shortcuts.xml не осталось ни одного ярлыка");

      for (final link in links) {
        final uri = Uri.parse(link);
        expect(uri.host, siteHostFull,
            reason: "хост ярлыка не совпадает с заверяемым фильтром манифеста"
                " — система отдаст адрес браузеру, а не приложению");

        // Движок превращает путь адреса в имя маршрута; пустой путь — главная.
        final routeName = uri.path.isEmpty ? "/" : uri.path;
        expect(_resolves(routeName), isTrue,
            reason: "ярлык $link ведёт в $routeName, а такой маршрут"
                " без аргумента не открывается");
      }
    });
  });
}
