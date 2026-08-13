import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _prefsKey = "reading_progress";

/// A text counts as finished past this scroll fraction — the saved
/// position is dropped instead of updated.
const double finishedFraction = 0.95;

/// Below this fraction there isn't enough progress worth remembering.
const double minMeaningfulFraction = 0.02;

class ReadingProgress {
  final double fraction;
  final DateTime updatedAt;

  ReadingProgress(this.fraction, this.updatedAt);

  Map<String, dynamic> toJson() => {
    'fraction': fraction,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  static ReadingProgress fromJson(Map<String, dynamic> json) => ReadingProgress(
    (json['fraction'] as num).toDouble(),
    DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
  );
}

Future<Map<String, dynamic>> _readAll() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null) return {};
  try {
    return Map<String, dynamic>.from(jsonDecode(raw));
  } catch (_) {
    return {};
  }
}

Future<void> _writeAll(Map<String, dynamic> all) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, jsonEncode(all));
}

Future<ReadingProgress?> getReadingProgress(String textId) async {
  final all = await _readAll();
  final entry = all[textId];
  if (entry == null) return null;
  try {
    return ReadingProgress.fromJson(Map<String, dynamic>.from(entry));
  } catch (_) {
    return null;
  }
}

Future<void> saveReadingProgress(String textId, double fraction) async {
  if (fraction >= finishedFraction) {
    await clearReadingProgress(textId);
    return;
  }
  if (fraction < minMeaningfulFraction) return;
  final all = await _readAll();
  all[textId] = ReadingProgress(fraction, DateTime.now()).toJson();
  await _writeAll(all);
}

Future<void> clearReadingProgress(String textId) async {
  final all = await _readAll();
  if (all.remove(textId) != null) {
    await _writeAll(all);
  }
}
