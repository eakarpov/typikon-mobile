import 'dart:convert';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

typedef CompanionJson = Map<String, dynamic>;
CompanionJson companionMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : {};
List<CompanionJson> companionList(dynamic v) => v is List
    ? v.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : [];
CompanionJson companionCopy(CompanionJson v) =>
    companionMap(jsonDecode(jsonEncode(v)));
String companionSignature(CompanionJson selection) {
  final allowed = selection['mode'] == 'study'
      ? const {'mode', 'ordo', 'lang'}
      : const {'mode', 'date', 'service', 'part', 'variant', 'ustav', 'lang'};
  final keys =
      selection.keys
          .where(
            (k) =>
                allowed.contains(k) &&
                selection[k] != null &&
                selection[k] != '',
          )
          .toList()
        ..sort();
  return jsonEncode({for (final k in keys) k: selection[k]});
}

String companionOperationId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
CompanionJson initialCompanionProgress() => {
  'revision': 0,
  'entries': <String, dynamic>{},
  'receipts': <String>[],
};
String companionNormalize(String s) => unorm
    .nfd(s)
    .toLowerCase()
    .replaceAll(RegExp(r'\p{M}+', unicode: true), '')
    .replaceAll('ѣ', 'е')
    .replaceAll('є', 'е')
    .replaceAll('ѿ', 'от')
    .replaceAll('ѳ', 'ф')
    .replaceAll('ѵ', 'и')
    .replaceAll('ѕ', 'з')
    .replaceAll('й', 'и')
    .replaceAll('ё', 'е')
    .replaceAll(RegExp('[ѧꙗ]'), 'я')
    .replaceAll(RegExp('[ꙋѹ]'), 'у')
    .replaceAll(RegExp('[іi]'), 'и')
    .replaceAll('ς', 'σ')
    .replaceAll('ѡ', 'о')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();
List<CompanionJson> companionSearch(CompanionJson service, String phrase) {
  final q = companionNormalize(phrase);
  if (q.isEmpty) return [];
  return companionList(service['nodes'])
      .where(
        (n) =>
            companionNormalize(n['title'] as String? ?? '').contains(q) ||
            companionList(n['lines']).any(
              (l) =>
                  l['audible'] == true &&
                  companionNormalize(l['text'] as String? ?? '').contains(q),
            ),
      )
      .toList();
}

List<CompanionJson> companionSearchOccurrences(
  CompanionJson service,
  String query,
) {
  final q = companionNormalize(query);
  if (q.isEmpty) return [];
  return companionList(service['nodes']).expand((n) {
    final hits = companionList(n['lines'])
        .where(
          (l) =>
              l['audible'] == true &&
              companionNormalize('${l['text'] ?? ''}').contains(q),
        )
        .map(
          (l) => <String, dynamic>{
            'nodeId': n['id'],
            'lineId': l['id'],
            'title': n['title'],
            'context': companionExcerpt('${l['text']}', query),
          },
        )
        .toList();
    if (hits.isEmpty && companionNormalize('${n['title']}').contains(q))
      hits.add({
        'nodeId': n['id'],
        'title': n['title'],
        'context': n['audibleCue'] ?? '',
      });
    return hits;
  }).toList();
}

CompanionJson companionEntry(
  CompanionJson service,
  CompanionJson selection,
  CompanionJson node, {
  CompanionJson? line,
}) => {
  'key': service['sessionKey'],
  'snapshotId': service['id'],
  'nodeId': node['id'],
  'contentHash': node['contentHash'],
  if (line != null) 'lineId': line['id'],
  if (line != null) 'lineHash': line['contentHash'],
  'title': service['title'],
  'nodeTitle': node['title'],
  'selection': {
    for (final e in selection.entries)
      if (e.value != null && e.value != '') e.key: e.value,
  },
  'saved': <String, dynamic>{},
};
CompanionJson applyCompanionOperation(
  CompanionJson original,
  CompanionJson op,
) {
  if ((original['receipts'] as List).contains(op['id'])) return original;
  if (op['revision'] != original['revision']) throw StateError('conflict');
  final s = companionCopy(original),
      entry = companionCopy(companionMap(op['entry']));
  for (final key in ['key', 'snapshotId', 'nodeId', 'contentHash']) {
    if (entry[key] is! String ||
        !RegExp(r'^[a-zA-Z0-9:_-]{1,160}$').hasMatch(entry[key]) ||
        ['__proto__', 'constructor', 'prototype'].contains(entry[key]))
      throw const FormatException('Неверное сохранённое место.');
  }
  if (entry['lineId'] != null || entry['lineHash'] != null) {
    for (final k in ['lineId', 'lineHash']) {
      if (entry[k] is! String ||
          !RegExp(r'^[a-zA-Z0-9:_-]{1,160}$').hasMatch(entry[k]))
        throw const FormatException('Неверное место внутри части.');
    }
  }
  final entries = companionMap(s['entries']);
  s['entries'] = entries;
  if (op['action'] == 'remove') {
    entries.remove(entry['key']);
  } else if (['position', 'save'].contains(op['action'])) {
    final old = companionMap(entries[entry['key']]),
        saved = companionMap(old['saved']),
        details = companionMap(old['savedDetails']);
    if (op['action'] == 'save') {
      if (op['done'] is! bool) throw const FormatException('Неверная отметка.');
      saved[entry['nodeId']] = op['done'];
      details[entry['nodeId']] = {
        'contentHash': entry['contentHash'],
        'title': entry['nodeTitle'],
      };
    }
    entry['saved'] = saved;
    entry['savedDetails'] = details;
    entry['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    entries[entry['key']] = entry;
  } else {
    throw const FormatException('Неверная операция.');
  }
  if (entries.length > 200)
    throw const FormatException('Сохранено слишком много служб.');
  s['revision'] = (s['revision'] as int) + 1;
  s['receipts'] = [...(s['receipts'] as List), op['id']];
  if ((s['receipts'] as List).length > 2000)
    s['receipts'] = (s['receipts'] as List).sublist(
      (s['receipts'] as List).length - 2000,
    );
  return s;
}

CompanionJson? companionRestore(CompanionJson service, CompanionJson entry) {
  final nodes = companionList(service['nodes']);
  final found = nodes
      .where(
        (n) =>
            n['id'] == entry['nodeId'] &&
            (entry['lineId'] != null
                ? companionList(n['lines']).any(
                    (l) =>
                        l['id'] == entry['lineId'] &&
                        l['contentHash'] == entry['lineHash'],
                  )
                : n['contentHash'] == entry['contentHash']),
      )
      .firstOrNull;
  if (found != null &&
      service['id'] != entry['snapshotId'] &&
      nodes
              .where(
                (n) =>
                    '${n['id']}'.split(':').first ==
                    '${found['id']}'.split(':').first,
              )
              .length >
          1)
    return null;
  return found;
}

class CompanionBundle {
  final CompanionJson data;
  const CompanionBundle(this.data);
  List<CompanionJson> get services => companionList(data['services']);
  factory CompanionBundle.fromJson(dynamic raw) {
    final d = companionMap(raw);
    if (d['schemaVersion'] != 1 ||
        d['services'] is! List ||
        d['sources'] is! List)
      throw const FormatException('Неверный формат Спутника.');
    if (companionList(d['services']).length != (d['services'] as List).length ||
        (d['services'] as List).isEmpty ||
        (d['services'] as List).length > 16)
      throw const FormatException('Неверный список служб.');
    var count = 0;
    bool note(dynamic raw) {
      final n = companionMap(raw);
      return [
            'title',
            'summary',
            'detail',
            'author',
          ].every((k) => n[k] is String) &&
          n['sourceRefs'] is List &&
          (n['furtherReading'] == null || n['furtherReading'] is List);
    }

    for (final s in companionList(d['services'])) {
      if (!['id', 'sessionKey', 'title'].every((k) => s[k] is String) ||
          s['nodes'] is! List ||
          s['coverage'] is! Map ||
          !note(s['guide']))
        throw const FormatException('Неверная служба.');
      if (companionList(s['nodes']).length != (s['nodes'] as List).length)
        throw const FormatException('Неверная карта.');
      for (final n in companionList(s['nodes'])) {
        if (!['id', 'title', 'contentHash'].every((k) => n[k] is String) ||
            !note(n['explanation']) ||
            (n['repeatCount'] != null && n['repeatCount'] is! num) ||
            n['lines'] is! List ||
            n['evidence'] is! List ||
            n['wordSenses'] is! List)
          throw const FormatException('Неверная часть службы.');
        for (final w in companionList(n['wordSenses'])) {
          if (w['forms'] is! List ||
              !(w['forms'] as List).every((f) => f is String) ||
              !note(w['explanation']))
            throw const FormatException('Неверная справка.');
        }
        if (companionList(n['lines']).length != (n['lines'] as List).length)
          throw const FormatException('Неверные строки.');
        for (final l in companionList(n['lines'])) {
          if (l['translations'] is! List ||
              (l['text'] != null && l['text'] is! String))
            throw const FormatException('Неверная строка.');
          if ((l['repeatCount'] != null && l['repeatCount'] is! num) ||
              (l['label'] != null && l['label'] is! String))
            throw const FormatException('Неверная рубрика.');
          for (final t in companionList(l['translations']))
            if (t['text'] is! String)
              throw const FormatException('Неверная параллель.');
          count++;
          if (count > 30000)
            throw const FormatException('Слишком много строк.');
        }
      }
    }
    return CompanionBundle(d);
  }
  factory CompanionBundle.fromPackage(List<int> bytes) {
    if (bytes.length > 40 * 1024 * 1024)
      throw const FormatException('Слишком большой файл .ordo.');
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.files.length > 4096 ||
        archive.files.fold<int>(0, (n, f) => n + f.size) > 64 * 1024 * 1024) {
      throw const FormatException('Слишком большой распакованный пакет.');
    }
    var total = 0;
    ArchiveFile? layer;
    for (final f in archive) {
      if (['companion.json', 'manifest.json'].contains(f.name)) {
        total += f.size;
        if (total > 32 * 1024 * 1024)
          throw const FormatException('Слишком большой слой Спутника.');
      }
      if (f.name == 'companion.json') layer = f;
    }
    if (layer == null)
      throw const FormatException(
        'В этом .ordo нет материалов Спутника. Откройте его в «Службе дня».',
      );
    final d = CompanionBundle.fromJson(
      jsonDecode(utf8.decode(layer.content as List<int>)),
    ).data;
    if (companionList(d['services']).length > 16)
      throw const FormatException('Слишком много служб.');
    var count = 0;
    for (final s in companionList(d['services'])) {
      if (s['nodes'] is! List || companionList(s['nodes']).length > 10000)
        throw const FormatException('Неверная карта службы.');
      for (final n in companionList(s['nodes'])) {
        count += companionList(n['lines']).length;
        if (count > 30000) throw const FormatException('Слишком много строк.');
      }
    }
    for (final raw in d['services'] as List) {
      final s = raw as Map;
      s['assemblyStatus'] =
          'Порядок из файла; назначение и календарные основания не подтверждены.';
      for (final r in (s['rules'] as List? ?? []).whereType<Map>()) {
        r['verified'] = false;
        r['status'] = 'Основание из файла, сверка не подтверждена';
      }
      for (final n in (s['nodes'] as List).whereType<Map>())
        for (final e in (n['evidence'] as List).whereType<Map>())
          e['verified'] = false;
    }
    // An imported archive cannot certify its own explanations or their placement.
    return CompanionBundle({...d, 'trusted': false});
  }
}

String companionExcerpt(String text, String query) {
  if (text.length < 260) return text;
  final normalized = companionNormalize(text),
      q = companionNormalize(query),
      at = companionNormalize(text).indexOf(companionNormalize(query));
  final start = max(0, at - 70),
      end = min(normalized.length, at + q.length + 130);
  return '${at > 70 ? '…' : ''}${normalized.substring(start, end)}…';
}

CompanionJson companionImportedSelection(CompanionJson service) {
  final s = companionMap(service['selection']), use = companionMap(s['use']);
  final date = s['date'];
  final parsed = date is String ? DateTime.tryParse(date) : null;
  if (s['mode'] == 'day' &&
      date is String &&
      parsed != null &&
      parsed.year >= 1900 &&
      parsed.year <= 2099 &&
      parsed.toIso8601String().startsWith(date) &&
      s['service'] is String)
    return {
      'mode': 'day',
      'date': date,
      'service': s['service'],
      if (s['stoyanie'] is String) 'part': s['stoyanie'],
      if (s['variant'] is String) 'variant': s['variant'],
      if (use['rite'] is String && use['tradition'] is String)
        'ustav': '${use['rite']}/${use['tradition']}',
    };
  if (s['ordoId'] is! String)
    throw const FormatException('В файле не указан источник последования.');
  return {'mode': 'study', 'ordo': s['ordoId']};
}

String companionMissingText(dynamic reason) =>
    const {
      'rights': 'Текст этого издания недоступен для выдачи.',
      'unset': 'Текст для этого места пока не определён сборщиком.',
      'external': 'Текст Писания не загружен.',
      'omitted': 'Текст не включён в этот пакет.',
      'not-collected': 'Текст этого издания пока не включён в корпус.',
    }[reason] ??
    'Текст недоступен.';
