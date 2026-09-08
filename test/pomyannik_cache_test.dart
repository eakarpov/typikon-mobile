import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/dto/pomyannik.dart';
import 'package:typikon/store/pomyannik_cache.dart';

// Зеркало ближайших дней — единственное место, где помянник ложится на диск.
// В нём чужие даты смерти, и после выхода из учётной записи его быть не должно.
//
// Путей выхода два: осознанный (`signOut`) и вынужденный, когда сессию не
// удалось продлить (`forgetSession`). Очистка, поставленная на один из них,
// выглядит в коде сделанной — и не работает на другом. Так и вышло: на
// устройстве файл пережил выход через настройки.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp("pomyannik");
    pomyannikDirectory = () async => directory;
  });

  tearDown(() async {
    resetPomyannikDirectory();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  PomyannikMirror mirror() => PomyannikMirror(
        userId: "user-1",
        fetchedAt: DateTime(2026, 9, 8, 9),
        from: "2026-09-08",
        days: 60,
        events: [
          const UpcomingEvent(
            date: "2026-09-08",
            kind: "fortieth",
            title: "Сороковой день: Николай",
            personId: "p1",
          ),
        ],
      );

  Future<String?> onDisk() async {
    final file = File("${directory.path}/pomyannik_upcoming.json");
    return await file.exists() ? file.readAsString() : null;
  }

  test("имена на диск не ложатся, пока их не разрешили", () async {
    await writePomyannikMirror(mirror(), withNames: false);

    final saved = jsonDecode((await onDisk())!);
    expect(saved["events"].single["title"], "");
    expect(saved["events"].single["date"], "2026-09-08");
    expect(saved["userId"], "user-1");
  });

  test("разрешённые имена пишутся как есть", () async {
    await writePomyannikMirror(mirror(), withNames: true);

    final saved = jsonDecode((await onDisk())!);
    expect(saved["events"].single["title"], "Сороковой день: Николай");
  });

  test("выход стирает зеркало, а не прячет его", () async {
    await writePomyannikMirror(mirror(), withNames: true);
    expect(await onDisk(), isNotNull);

    await clearPomyannikCache();

    expect(await onDisk(), isNull);
    expect(await readPomyannikMirror(), isNull);
  });

  test("выход стирает и отметку о последнем напоминании", () async {
    await rememberPomyannikNotice("2026-09-08");
    expect(await lastPomyannikNotice(), "2026-09-08");

    await clearPomyannikCache();

    expect(await lastPomyannikNotice(), isNull);
  });

  test("прочитанное с диска возвращается тем же", () async {
    await writePomyannikMirror(mirror(), withNames: true);

    final read = await readPomyannikMirror();

    expect(read!.userId, "user-1");
    expect(read.from, "2026-09-08");
    expect(read.on("2026-09-08").single.title, "Сороковой день: Николай");
    expect(read.on("2026-09-09"), isEmpty);
  });
}
