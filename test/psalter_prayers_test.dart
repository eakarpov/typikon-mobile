import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typikon/apiMapper/session.dart';
import 'package:typikon/apiMapper/v2/errors.dart';
import 'package:typikon/dto/prayer_text.dart';
import 'package:typikon/store/psalter_prayers.dart';

// Загрузка молитв с именами для поминального чтения: успех пишет снимок,
// сбой честно решает — свежий снимок без плашки, протухший с плашкой, без
// снимка — «недоступны», без входа — «войдите». Порог свежести — 12 часов.

NamedPrayersFetcher failing(Object error) =>
    ({required String forKind, required String gender, String? style}) async {
      throw error;
    };

NamedPrayersFetcher byKind() =>
    ({required String forKind, required String gender, String? style}) async =>
        <NamedPrayer>[
          NamedPrayer(id: "$forKind-$gender", text: "Молитва $forKind"),
        ];

void main() {
  final now = DateTime(2026, 10, 14, 12, 0);

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'чужой аккаунт и старый снимок не подставляют сохранённые имена',
    () async {
      await savePsalterNamedPrayersSnapshot(
        ownerId: 'account-a',
        gender: 'm',
        departed: const [NamedPrayer(text: 'Имя первого аккаунта')],
        living: const [],
      );
      final result = await loadPsalterNamedPrayers(
        ownerId: 'account-b',
        gender: 'm',
        fetch: failing(Exception('offline')),
      );
      expect(result.unavailable, true);
      expect(result.departed, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'psalter_named_prayers',
        '{"fetchedAt":1,"gender":"m","prayers":{"departed":[{"text":"Александра"}]}}',
      );
      final legacy = await loadPsalterNamedPrayers(
        gender: 'm',
        fetch: failing(Exception('offline')),
      );
      expect(legacy.unavailable, true);
      expect(legacy.departed, isEmpty);
    },
  );

  test('в поминальном режиме запрашиваются исключительно усопшие', () async {
    final kinds = <String>[];
    await loadPsalterNamedPrayers(
      fetch: ({required forKind, required gender, style}) async {
        kinds.add(forKind);
        return const [NamedPrayer(text: 'Молитва об усопших')];
      },
    );
    expect(kinds, ['departed']);
  });

  test('отказ ключа не предлагает снова входить через Google', () async {
    final result = await loadPsalterNamedPrayers(
      fetch: failing(const ApiUnauthorizedException('Нет доступа')),
    );
    expect(result.accessDenied, true);
    expect(result.signInNeeded, false);
  });

  test('используется поминовение Псалтири без запроса литии', () async {
    final result = await loadPsalterNamedPrayers(
      fetch: ({required forKind, required gender, style}) async {
        expect(style, 'psalter-departed');
        return [NamedPrayer(text: 'Имя $forKind')];
      },
    );
    expect(result.departed.single.text, 'Имя departed');
    expect(result.living, isEmpty);
    expect(result.unavailable, false);
  });

  test("успех: только усопшие, снимок записан", () async {
    final result = await loadPsalterNamedPrayers(
      gender: "m",
      fetch: byKind(),
      now: now,
    );

    expect(result.unavailable, isFalse);
    expect(result.signInNeeded, isFalse);
    expect(result.stale, isFalse);
    expect(result.departed.map((p) => p.id), <String>["departed-m"]);
    expect(result.living, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString("psalter_named_prayers"), isNotNull);
  });

  test("сбой со свежим снимком (<12 ч): показан без плашки", () async {
    await savePsalterNamedPrayersSnapshot(
      gender: "m",
      departed: const <NamedPrayer>[NamedPrayer(id: "d", text: "об усопших")],
      living: const <NamedPrayer>[NamedPrayer(id: "l", text: "о живых")],
      now: now.subtract(const Duration(hours: 1)),
    );

    final result = await loadPsalterNamedPrayers(
      gender: "m",
      fetch: failing(Exception("нет сети")),
      now: now,
    );

    expect(result.unavailable, isFalse);
    expect(result.stale, isFalse);
    expect(result.departed.single.id, "d");
    expect(result.living, isEmpty);
  });

  test("сбой со снимком старше 12 ч: показан, но с плашкой stale", () async {
    await savePsalterNamedPrayersSnapshot(
      gender: "m",
      departed: const <NamedPrayer>[NamedPrayer(id: "d", text: "об усопших")],
      living: const <NamedPrayer>[],
      now: now.subtract(const Duration(hours: 13)),
    );

    final result = await loadPsalterNamedPrayers(
      gender: "m",
      fetch: failing(Exception("нет сети")),
      now: now,
    );

    expect(result.unavailable, isFalse);
    expect(result.stale, isTrue);
    expect(result.departed.single.id, "d");
  });

  test("сбой без снимка: честно unavailable", () async {
    final result = await loadPsalterNamedPrayers(
      gender: "m",
      fetch: failing(Exception("нет сети")),
      now: now,
    );

    expect(result.unavailable, isTrue);
    expect(result.hasPrayers, isFalse);
  });

  test("протухшая сессия: signInNeeded, молитв нет", () async {
    final result = await loadPsalterNamedPrayers(
      gender: "m",
      fetch: failing(const SessionExpiredException()),
      now: now,
    );

    expect(result.signInNeeded, isTrue);
    expect(result.hasPrayers, isFalse);
    expect(result.unavailable, isFalse);
  });

  test("снимок чужого рода не берём: unavailable, а не чужие тексты", () async {
    await savePsalterNamedPrayersSnapshot(
      gender: "f",
      departed: const <NamedPrayer>[NamedPrayer(id: "d", text: "о рабах")],
      living: const <NamedPrayer>[],
      now: now.subtract(const Duration(hours: 1)),
    );

    final result = await loadPsalterNamedPrayers(
      gender: "m",
      fetch: failing(Exception("нет сети")),
      now: now,
    );

    expect(result.unavailable, isTrue);
  });

  test("снимок своего рода берём даже после сбоя", () async {
    await savePsalterNamedPrayersSnapshot(
      gender: "f",
      departed: const <NamedPrayer>[NamedPrayer(id: "d", text: "о рабах")],
      living: const <NamedPrayer>[],
      now: now.subtract(const Duration(hours: 1)),
    );

    final result = await loadPsalterNamedPrayers(
      gender: "f",
      fetch: failing(Exception("нет сети")),
      now: now,
    );

    expect(result.unavailable, isFalse);
    expect(result.departed.single.id, "d");
  });
}
