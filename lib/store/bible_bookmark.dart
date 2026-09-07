import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Закладка в Библии: где читатель остановился.
///
/// Устройство то же, что у `reading_progress.dart` — свой ключ в
/// `SharedPreferences`, мимо Redux, — а вот величина другая, и это решение.
///
/// **Место, а не доля прокрутки.** Глава помещается в один-два экрана, и «вы
/// остановились на 43 %» не говорит читателю ничего, тогда как «Вы читали: От
/// Матфея, глава 19» говорит всё. Доля прокрутки нужна на длинном тексте, где
/// потерять место дорого; здесь она была бы ложной точностью.
///
/// **Одна на всю Библию, а не по книге.** Закладка на книгу — это уже список
/// «что я где читаю», то есть другая вещь, со своим экраном и своей уборкой.
/// Одна закладка отвечает на единственный вопрос, который возникает при открытии
/// раздела: «куда я вчера дошёл».
///
/// Имя книги здесь не хранится: оглавление его и так знает, а вторая копия
/// разошлась бы с сервером после переименования.
const String _prefsKey = "bible_bookmark";

class BibleBookmark {
  final String canonId;
  final int chapter;

  const BibleBookmark(this.canonId, this.chapter);
}

Future<BibleBookmark?> getBibleBookmark() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return null;

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    final canonId = decoded["canonId"];
    final chapter = decoded["chapter"];
    if (canonId is! String || canonId.isEmpty) return null;
    if (chapter is! int || chapter < 1) return null;

    return BibleBookmark(canonId, chapter);
  } catch (_) {
    return null;
  }
}

Future<void> saveBibleBookmark(String canonId, int chapter) async {
  if (canonId.isEmpty || chapter < 1) return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, jsonEncode({
    "canonId": canonId,
    "chapter": chapter,
  }));
}

Future<void> clearBibleBookmark() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_prefsKey);
}
