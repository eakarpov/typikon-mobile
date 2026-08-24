import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:typikon/api/constants.dart';
import 'package:typikon/dto/version.dart';
import 'package:typikon/utils/app_version.dart';
import 'package:typikon/version.dart';

void main() {
  group("сравнение версий", () {
    test("больший минор при том же мажоре — обновление есть", () {
      expect(
        isUpdateAvailable(Version(major: majorVersion, minor: minorVersion + 1)),
        isTrue,
      );
    });

    test("та же версия — обновления нет", () {
      expect(
        isUpdateAvailable(Version(major: majorVersion, minor: minorVersion)),
        isFalse,
      );
    });

    test("больший мажор — обновление есть даже при меньшем миноре", () {
      expect(
        isUpdateAvailable(Version(major: majorVersion + 1, minor: 0)),
        isTrue,
      );
    });

    test("меньший мажор с большим минором обновлением не считается", () {
      // Ровно та ошибка, из-за которой сравнение и переписано: при
      // установленной 2.0 сервер с 1.9 предлагал "обновиться" назад.
      expect(
        isUpdateAvailable(Version(major: majorVersion - 1, minor: minorVersion + 9)),
        isFalse,
      );
    });
  });

  test("appVersion не разъехался с pubspec.yaml", () {
    // Третья копия версии на клиенте: её приложение шлёт заголовком
    // X-Typikon-App и прикладывает к отчётам о падениях. Разъедется —
    // и статистика по версиям, и отчёты начнут врать.
    final pubspec = File("pubspec.yaml").readAsStringSync();
    final match = RegExp(r"^version:\s*(\S+)", multiLine: true).firstMatch(pubspec);

    expect(match, isNotNull);
    expect(appVersion, match!.group(1));
  });

  test("version.dart не разъехался с pubspec.yaml", () {
    final pubspec = File("pubspec.yaml").readAsStringSync();
    final match = RegExp(r"^version:\s*(\d+)\.(\d+)\.", multiLine: true).firstMatch(pubspec);

    expect(match, isNotNull, reason: "в pubspec.yaml не нашлась строка version:");

    final pubspecMajor = int.parse(match!.group(1)!);
    final pubspecMinor = int.parse(match.group(2)!);

    expect(
      [majorVersion, minorVersion],
      [pubspecMajor, pubspecMinor],
      reason: "lib/version.dart и pubspec.yaml задают версию по отдельности; "
          "после подъёма версии нужно менять оба, иначе приложение начнёт "
          "предлагать обновиться само на себя",
    );
  });
}
