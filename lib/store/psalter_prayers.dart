import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../apiMapper/prayer_text.dart' show getNamedPrayers;
import '../apiMapper/session.dart' show SessionExpiredException;
import '../apiMapper/v2/errors.dart' show ApiUnauthorizedException;
import '../dto/pomyannik.dart' show departed, living;
import '../dto/prayer_text.dart';
import 'rule_marks.dart' show ruleGender;

/// Молитвы с именами для поминального чтения Псалтири: разовая загрузка
/// и офлайн-снимок.
///
/// Ручка личная и её ответ — имена родни, поэтому два решения, отличных от
/// общего http-кэша:
///
/// **Снимок — свой ключ** (`psalter_named_prayers` в `SharedPreferences`),
/// а не `cachedFetch`: класть имена в общий кэш-каталог, который чистит и
/// система, и кнопка «сбросить кэш», негде.
///
/// **Свежесть — двенадцать часов.** Состав помянника меняется от записи, и
/// молча читать неделю по снимку нельзя: снимок старше [namedPrayersFreshFor],
/// показанный после неудачной загрузки, подписан честной плашкой «Имена не
/// обновлены (нет сети); показан сохранённый состав». Свежий снимок (в пределах
/// тех же двенадцати часов) после сбоя сети показываем без плашки — состав за
/// это время можно считать актуальным.
///
/// **Отказы названы своими именами.** Сессия истекла — [signInNeeded]: читать
/// «с именами» можно только вошедшему, и кафизма при этом читается как обычно,
/// без молитв. Сеть пропала и снимка нет — [unavailable]: блок молитв заменяет
/// плашка «Молитвы с именами недоступны без сети».

/// Снимок годен двенадцать часов с момента записи.
const Duration namedPrayersFreshFor = Duration(hours: 12);

const String _prefsKey = "psalter_named_prayers";

class PsalterNamedPrayers {
  /// Молитвы об усопших — вставляются после «Слава».
  final List<NamedPrayer> departed;

  /// Молитвы о живых — вставляются после «И ныне».
  final List<NamedPrayer> living;

  /// Показан сохранённый состав после неудачной загрузки, и состав этот
  /// протух (снимку больше [namedPrayersFreshFor]).
  final bool stale;

  /// Загрузка не удалась и снимка нет (или он чужого рода): блока молитв
  /// не будет вовсе, вместо него — плашка.
  final bool unavailable;

  /// Не вошли, а ручка личная: молитв с именами не будет, пока не войдут.
  final bool signInNeeded;

  const PsalterNamedPrayers({
    this.departed = const <NamedPrayer>[],
    this.living = const <NamedPrayer>[],
    this.stale = false,
    this.unavailable = false,
    this.signInNeeded = false,
  });

  bool get hasPrayers => departed.isNotEmpty || living.isNotEmpty;
}

/// Подменяется тестами; в приложении — два запроса к `/api/v2/prayer-text`.
typedef NamedPrayersFetcher =
    Future<List<NamedPrayer>> Function({required String forKind, required String gender});

/// Разово грузит оба набора молитв (об усопших и о живых) и обновляет снимок.
/// Не удалось — честно отвечает, чем пришлось заменить живые данные.
Future<PsalterNamedPrayers> loadPsalterNamedPrayers({
  String? gender,
  NamedPrayersFetcher? fetch,
  DateTime? now,
}) async {
  final g = gender == "f" ? "f" : "m";
  final effectiveGender = gender == null ? await ruleGender() : g;
  final fetcher = fetch ?? getNamedPrayers;
  try {
    final departedPrayers =
        await fetcher(forKind: departed, gender: effectiveGender);
    final livingPrayers = await fetcher(forKind: living, gender: effectiveGender);
    await savePsalterNamedPrayersSnapshot(
      gender: effectiveGender,
      departed: departedPrayers,
      living: livingPrayers,
      now: now,
    );
    return PsalterNamedPrayers(departed: departedPrayers, living: livingPrayers);
  } on SessionExpiredException {
    return const PsalterNamedPrayers(signInNeeded: true);
  } on ApiUnauthorizedException {
    return const PsalterNamedPrayers(signInNeeded: true);
  } catch (_) {
    final snapshot = await _readPsalterNamedPrayersSnapshot(
      gender: effectiveGender,
    );
    if (snapshot == null) {
      return const PsalterNamedPrayers(unavailable: true);
    }
    final age = (now ?? DateTime.now()).difference(snapshot.fetchedAt);
    return PsalterNamedPrayers(
      departed: snapshot.departed,
      living: snapshot.living,
      stale: age > namedPrayersFreshFor,
    );
  }
}

class _Snapshot {
  final DateTime fetchedAt;
  final String gender;
  final List<NamedPrayer> departed;
  final List<NamedPrayer> living;

  const _Snapshot({
    required this.fetchedAt,
    required this.gender,
    required this.departed,
    required this.living,
  });
}

/// Снимок, как его писать. Род записываем вместе с текстами: молитва о живых
/// спрашивает «раба» или «рабы» по-разному, и снимок чужого рода показывать
/// хуже, чем никакого.
Future<void> savePsalterNamedPrayersSnapshot({
  required String gender,
  required List<NamedPrayer> departed,
  required List<NamedPrayer> living,
  DateTime? now,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _prefsKey,
    jsonEncode({
      "fetchedAt": (now ?? DateTime.now()).millisecondsSinceEpoch,
      "gender": gender,
      "prayers": {
        "departed": departed.map((p) => p.toJson()).toList(),
        "living": living.map((p) => p.toJson()).toList(),
      },
    }),
  );
}

/// Снимок, как его читать. `null` — нет ключа, битый JSON или чужой род:
/// ни одно из этих состояний не годится, чтобы подставить имена в молитву.
Future<_Snapshot?> _readPsalterNamedPrayersSnapshot({String? gender}) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return null;

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final fetchedAt = decoded["fetchedAt"];
    if (fetchedAt is! int) return null;
    final savedGender = decoded["gender"];
    if (savedGender is! String) return null;
    if (gender != null && savedGender != gender) return null;

    final prayers = decoded["prayers"];
    if (prayers is! Map) return null;

    List<NamedPrayer> list(dynamic value) => value is List
        ? value
            .whereType<Map>()
            .map((row) => NamedPrayer.fromJson(Map<String, dynamic>.from(row)))
            .toList()
        : const <NamedPrayer>[];

    return _Snapshot(
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAt),
      gender: savedGender,
      departed: list(prayers["departed"]),
      living: list(prayers["living"]),
    );
  } catch (_) {
    return null;
  }
}
