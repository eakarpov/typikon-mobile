import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../apiMapper/prayer_text.dart' show getNamedPrayers;
import '../apiMapper/session.dart' show SessionExpiredException;
import '../apiMapper/v2/errors.dart' show ApiUnauthorizedException;
import '../dto/pomyannik.dart' show departed;
import '../dto/prayer_text.dart';
import 'rule_marks.dart' show ruleGender;
import 'store.dart' show appStore;

/// Молитвы об усопших для слав и окончания кафизмы.
/// Имена подставляет сервер; локальный снимок отделён от общего HTTP-кэша,
/// привязан к аккаунту и роду. Снимки до версии 3 не принимаются.
/// После сбоя снимок старше [namedPrayersFreshFor] показывается с плашкой.
/// Тропари не зависят от сессии и загрузки имён.

/// Снимок годен двенадцать часов с момента записи.
const Duration namedPrayersFreshFor = Duration(hours: 12);

const String _prefsKey = "psalter_named_prayers";

class PsalterNamedPrayers {
  /// Молитвы об усопших — вставляются после «Слава».
  final List<NamedPrayer> departed;

  /// Старое поле совместимости. В поминовении об усопших не используется.
  final List<NamedPrayer> living;
  final bool accessDenied;

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
    this.accessDenied = false,
    this.stale = false,
    this.unavailable = false,
    this.signInNeeded = false,
  });

  bool get hasPrayers => departed.isNotEmpty;
}

/// Подменяется тестами; в приложении — один запрос к `/api/v2/prayer-text`.
typedef NamedPrayersFetcher =
    Future<List<NamedPrayer>> Function({
      required String forKind,
      required String gender,
      String? style,
    });

/// Загружает краткое поминовение: один список имён без родственных категорий.
/// При сбое используется только снимок того же аккаунта и рода.
Future<PsalterNamedPrayers> loadPsalterNamedPrayers({
  String? gender,
  NamedPrayersFetcher? fetch,
  DateTime? now,
  String? ownerId,
}) async {
  final owner = ownerId ?? appStore?.state.auth.userId;
  final g = gender == "f" ? "f" : "m";
  final effectiveGender = gender == null ? await ruleGender() : g;
  final fetcher = fetch ?? getNamedPrayers;
  try {
    final departedPrayers = await fetcher(
      forKind: departed,
      gender: effectiveGender,
      style: 'psalter-departed',
    );
    if (ownerId == null && owner != appStore?.state.auth.userId) {
      return const PsalterNamedPrayers(unavailable: true);
    }
    await savePsalterNamedPrayersSnapshot(
      gender: effectiveGender,
      departed: departedPrayers,
      living: const [],
      now: now,
      ownerId: owner,
    );
    return PsalterNamedPrayers(departed: departedPrayers);
  } on SessionExpiredException {
    return const PsalterNamedPrayers(signInNeeded: true);
  } on ApiUnauthorizedException {
    return const PsalterNamedPrayers(accessDenied: true);
  } catch (_) {
    final snapshot = await _readPsalterNamedPrayersSnapshot(
      gender: effectiveGender,
      ownerId: owner,
    );
    if (ownerId == null && owner != appStore?.state.auth.userId) {
      return const PsalterNamedPrayers(unavailable: true);
    }
    if (snapshot == null) {
      return const PsalterNamedPrayers(unavailable: true);
    }
    final age = (now ?? DateTime.now()).difference(snapshot.fetchedAt);
    return PsalterNamedPrayers(
      departed: snapshot.departed,
      stale: age > namedPrayersFreshFor,
    );
  }
}

class _Snapshot {
  final DateTime fetchedAt;
  final String gender;
  final List<NamedPrayer> departed;

  const _Snapshot({
    required this.fetchedAt,
    required this.gender,
    required this.departed,
  });
}

/// Запись снимка с владельцем и версией; молитвы о живых не сохраняются.
Future<void> savePsalterNamedPrayersSnapshot({
  required String gender,
  required List<NamedPrayer> departed,
  required List<NamedPrayer> living,
  DateTime? now,
  String? ownerId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _prefsKey,
    jsonEncode({
      "version": 3,
      "ownerId": ownerId ?? appStore?.state.auth.userId,
      "fetchedAt": (now ?? DateTime.now()).millisecondsSinceEpoch,
      "gender": gender,
      "prayers": {"departed": departed.map((p) => p.toJson()).toList()},
    }),
  );
}

/// Снимок, как его читать. `null` — нет ключа, битый JSON или чужой род:
/// ни одно из этих состояний не годится, чтобы подставить имена в молитву.
Future<_Snapshot?> _readPsalterNamedPrayersSnapshot({
  String? gender,
  String? ownerId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return null;

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    if (decoded['version'] != 3 || decoded['ownerId'] != ownerId) return null;
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
              .map(
                (row) => NamedPrayer.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList()
        : const <NamedPrayer>[];

    return _Snapshot(
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAt),
      gender: savedGender,
      departed: list(prayers["departed"]),
    );
  } catch (_) {
    return null;
  }
}
