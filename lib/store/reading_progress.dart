import 'dart:convert';
import 'psalter_serial_bookmark.dart';
import 'rule_cycle.dart';

import 'package:shared_preferences/shared_preferences.dart';

const String _prefsKey = "reading_progress";

/// A text counts as finished past this scroll fraction — the saved
/// position is dropped instead of updated.
const double finishedFraction = 0.95;

/// Below this fraction there isn't enough progress worth remembering.
const double minMeaningfulFraction = 0.02;

/// Сколько записей «продолжить чтение» показывается на главной: сверх этого
/// список обрезается, при том что сортируется он по свежести — отрезаться
/// могут только давно не открывавшиеся тексты.
const int maxProgressEntries = 50;

class ReadingProgress {
  final double fraction;
  final DateTime updatedAt;

  /// Имя текста для списка «продолжить чтение». `null` у записей, сохранённых
  /// до того, как имя стали запоминать, — старая запись не хуже новой, и
  /// ронять её из-за отсутствующего поля незачем.
  final String? name;

  ReadingProgress(this.fraction, this.updatedAt, {this.name});

  Map<String, dynamic> toJson() => {
    'fraction': fraction,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    if (name != null) 'name': name,
  };

  static ReadingProgress fromJson(Map<String, dynamic> json) => ReadingProgress(
    (json['fraction'] as num).toDouble(),
    DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
    name: json['name'] is String ? json['name'] as String : null,
  );
}

/// Сохранённое место одного текста: его идентификатор и сама запись.
class SavedReading {
  final String id;
  final ReadingProgress progress;

  const SavedReading(this.id, this.progress);
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

/// Все сохранённые места: по убыванию updatedAt, не больше [maxProgressEntries].
/// Безымянные (старые) записи не отбрасываются — решает показывающий экран.
Future<List<SavedReading>> getAllReadingProgress({DateTime? now}) async {
  final cycle = RuleCycle.at(now ?? DateTime.now());
  final all = await _readAll();
  final entries = <SavedReading>[];
  for (final entry in all.entries) {
    if (entry.key.startsWith('rule:') && entry.key != cycle.progressId) {
      continue;
    }
    try {
      entries.add(
        SavedReading(
          entry.key,
          ReadingProgress.fromJson(Map<String, dynamic>.from(entry.value)),
        ),
      );
    } catch (_) {
      // Одна порченая запись не должна ронять список целиком.
    }
  }
  final serial = await getPsalterSerialBookmark();
  if (serial != null) {
    entries.removeWhere((entry) => entry.id == 'psalter:serial');
    entries.add(
      SavedReading(
        'psalter:serial',
        ReadingProgress(
          ((serial.chapter - 1) / 151).clamp(0.0, 1.0),
          serial.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          name:
              'Псалтирь подряд: псалом ${serial.chapter}, стих ${serial.verse}',
        ),
      ),
    );
  }
  entries.sort((a, b) => b.progress.updatedAt.compareTo(a.progress.updatedAt));
  return entries.length > maxProgressEntries
      ? entries.sublist(0, maxProgressEntries)
      : entries;
}

Future<void> saveReadingProgress(
  String textId,
  double fraction, {
  String? name,
}) async {
  if (fraction >= finishedFraction) {
    await clearReadingProgress(textId);
    return;
  }
  if (fraction < minMeaningfulFraction) return;
  final all = await _readAll();
  // Имя не передали — сохранённое не затираем: прогресс пишется и на выходе,
  // и по дебаунсу, а имя текста на странице появляется с ответом сервера,
  // то есть ранние записи могли уйти вообще без имени.
  final previous = all[textId];
  final keptName = name ?? ((previous is Map) ? previous['name'] : null);
  all[textId] = ReadingProgress(
    fraction,
    DateTime.now(),
    name: keptName is String ? keptName : null,
  ).toJson();
  await _writeAll(all);
}

Future<void> clearReadingProgress(String textId) async {
  final all = await _readAll();
  if (all.remove(textId) != null) {
    await _writeAll(all);
  }
}
