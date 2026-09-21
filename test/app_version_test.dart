import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/api/constants.dart';
import 'package:typikon/dto/version.dart';
import 'package:typikon/utils/app_version.dart';
import 'package:typikon/version.dart';

// Версия. Ошибка здесь не видна никому: копия, считающая себя новее выложенного,
// просто никогда не предложит обновиться, и узнаем мы об этом от пользователя,
// который полгода сидит на старом.

void main() {
  test("номер в коде сходится с номером сборки", () {
    // Одно и то же число записано дважды: в pubspec его читают Android и iOS,
    // в version.dart — сверка с сервером. Разъехавшись, они не сломают ничего
    // заметного: копия будет предлагать обновиться сама на себя или молчать о
    // настоящем обновлении.
    final pubspec = File("pubspec.yaml").readAsStringSync();
    final line = RegExp(r"^version:\s*(\d+)\.(\d+)\.(\d+)", multiLine: true)
        .firstMatch(pubspec);

    expect(line, isNotNull, reason: "в pubspec.yaml нет строки version");
    expect(int.parse(line!.group(1)!), majorVersion);
    expect(int.parse(line.group(2)!), minorVersion);
    expect(int.parse(line.group(3)!), patchVersion);
  });

  test("заголовок X-Typikon-App несёт ту же версию, что и сборка", () {
    // Третья запись того же числа — `appVersion` в constants.dart, и её до сих
    // пор проверяли только на вид. По этому заголовку сервер считает долю
    // приложения среди клиентов первой версии API и решает, можно ли её
    // закрывать: разъехавшись, он припишет запросы не тому выпуску, и молча.
    final pubspec = File("pubspec.yaml").readAsStringSync();
    final version = RegExp(r"^version:\s*(\S+)", multiLine: true)
        .firstMatch(pubspec)!
        .group(1);

    expect(appVersion, version);
  });

  test("CHANGELOG знает о нынешнем выпуске", () {
    // Раздела 2.1.0 в нём не было: список изменений отстал на выпуск, а
    // заметить это можно было только заглянув в файл.
    final changelog = File("CHANGELOG.md").readAsStringSync();
    final expected = "$majorVersion.$minorVersion.$patchVersion";

    expect(
      RegExp("^#+\\s*$expected\\s*\$", multiLine: true).hasMatch(changelog),
      isTrue,
      reason: "в CHANGELOG.md нет раздела $expected",
    );
  });

  group("есть ли обновление", () {
    Version remote(int major, int minor, [int patch = 0]) =>
        Version(major: major, minor: minor, patch: patch);

    test("старший номер решает, а не набор чисел", () {
      // 1.9 против установленной 2.0: минор девять больше нуля, и сравнение
      // чисел порознь объявило бы обновлением откат назад.
      expect(isUpdateAvailable(remote(majorVersion - 1, minorVersion + 9)), isFalse);
      expect(isUpdateAvailable(remote(majorVersion + 1, 0)), isTrue);
    });

    test("своя же версия обновлением не считается", () {
      expect(isUpdateAvailable(remote(majorVersion, minorVersion, patchVersion)), isFalse);
    });

    test("патч замечается, когда старшие равны", () {
      // Патчей мы пока не выпускаем, но ручка их отдаёт: заметить 2.0.1 копия
      // должна с первого же такого выпуска, а не после правки сравнения.
      expect(isUpdateAvailable(remote(majorVersion, minorVersion, patchVersion + 1)), isTrue);
    });

    test("молчание сервера о патче не считается откатом", () {
      // Первая версия API отдаёт только major и minor, и патч приходит нулём.
      expect(isUpdateAvailable(remote(majorVersion, minorVersion)), isFalse);
    });
  });

  group("откуда брать выпуск", () {
    test("адрес называет сервер", () {
      // Переезд домена: старая копия узнает новый адрес выпуска от сервера, а
      // не склеит его из собственной константы.
      expect(
        updateUrl(const Version(major: 3, minor: 0, download: "https://typikon.info/app/app.apk")),
        "https://typikon.info/app/app.apk",
      );
    });

    test("не назвал — остаётся свой прежний", () {
      // Так отвечает первая версия API старым копиям.
      expect(updateUrl(const Version(major: 3, minor: 0)), endsWith("/app/app.apk"));
    });
  });

  group("разбор ответа", () {
    test("тройка и адрес читаются", () {
      final version = Version.fromJson({
        "version": "2.1.3", "major": 2, "minor": 1, "patch": 3,
        "download": "https://www.typikon.su/app/app.apk",
      });

      expect(version.toString(), "2.1.3");
      expect(version.download, "https://www.typikon.su/app/app.apk");
    });

    test("ответ первой версии API читается тем же разбором", () {
      final version = Version.fromJson({"major": 2, "minor": 0});

      expect(version.patch, 0);
      expect(version.download, isEmpty);
    });

    test("мусор в ответе не роняет проверку", () {
      // Проверка версий идёт фоновой задачей; исключение здесь не покажется
      // никому и просто отключит уведомления об обновлении.
      final version = Version.fromJson({"major": "два", "minor": null});

      expect(version.major, 0);
      expect(version.minor, 0);
    });
  });

  group("уведомление об обновлении", () {
    // Фоновая проверка идёт каждый час; говорить каждый час об одной и той же
    // версии — значит дождаться, что уведомления приложению выключат целиком.
    const newer = Version(major: majorVersion + 1, minor: 0);

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test("об одной версии говорим один раз", () async {
      expect(await claimUpdateNotification(newer), isTrue);
      expect(await claimUpdateNotification(newer), isFalse);
    });

    test("о следующей версии говорим снова", () async {
      await claimUpdateNotification(newer);
      expect(
        await claimUpdateNotification(const Version(major: majorVersion + 2, minor: 0)),
        isTrue,
      );
    });

    test("обновления нет — молчим и ничего не запоминаем", () async {
      const same = Version(major: majorVersion, minor: minorVersion, patch: patchVersion);
      expect(await claimUpdateNotification(same), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(updateNotifiedVersionKey), isNull);
    });
  });
}
