import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Закладка режима «Псалтирь подряд»: где читатель остановился.
///
/// Устройство то же, что у `bible_bookmark.dart` — свой ключ в
/// `SharedPreferences`, мимо Redux, — а величина другая, и это решение.
///
/// **Место, а не доля прокрутки.** «Вы остановились на псалме 43, стихе 5»
/// говорит читателю всё, а «вы на 17 %» — ничего: псалом помещается
/// в один-два экрана, и доля здесь была бы ложной точностью.
///
/// **Глава и стих — канонические**, славянского счёта: это те же номера,
/// которыми названа Псалтирь на экране, и по ним же глава запрашивается
/// у сервера (`psaltir`, глава == псалом).
const String _prefsKey = "psalter:serial";

class PsalterSerialBookmark {
  final int chapter;
  final int verse;

  const PsalterSerialBookmark(this.chapter, this.verse);
}

Future<PsalterSerialBookmark?> getPsalterSerialBookmark() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return null;

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    final chapter = decoded["chapter"];
    final verse = decoded["verse"];
    if (chapter is! int || chapter < 1) return null;
    if (verse is! int || verse < 1) return null;

    return PsalterSerialBookmark(chapter, verse);
  } catch (_) {
    return null;
  }
}

Future<void> savePsalterSerialBookmark(int chapter, int verse) async {
  if (chapter < 1 || verse < 1) return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, jsonEncode({
    "chapter": chapter,
    "verse": verse,
  }));
}

Future<void> clearPsalterSerialBookmark() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_prefsKey);
}
