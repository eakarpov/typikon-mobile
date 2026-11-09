import 'dart:convert';
import 'dart:math';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

typedef StudyJson = Map<String, dynamic>;
StudyJson studyMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : {};
List<StudyJson> studyList(dynamic v) =>
    v is List ? v.whereType<Map>().map(studyMap).toList() : [];
StudyJson emptyStudy() => {
  'records': <dynamic>[],
  'collections': <dynamic>[],
  'positions': <dynamic>[],
  'links': <dynamic>[],
};
String studyId() => List.generate(
  12,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
String studyNormalize(String s) => unorm
    .nfd(s)
    .replaceAll(RegExp(r'\p{M}', unicode: true), '')
    .toLowerCase()
    .replaceAll(RegExp('[іiѵ]'), 'и')
    .replaceAll('ѣ', 'е')
    .replaceAll('ς', 'σ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
String studyFingerprint(String s) {
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 16777619) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

String studyTargetKey(StudyJson t) => [
  t['kind'],
  t['id'],
  t['edition'] ?? '',
  t['chapter'] ?? '',
  t['statia'] ?? '',
].join(':');
StudyJson studyTargetAt(
  StudyJson m,
  StudyJson b, {
  String? quote,
  int? offset,
}) {
  final text = '${b['text'] ?? ''}',
      q = quote ?? text.substring(0, min(text.length, 2000)),
      at = offset ?? text.indexOf(q);
  return {
    ...studyMap(m['target']),
    'blockId': b['id'],
    'sourceHash': m['sourceHash'],
    if (b['verse'] != null) 'verseFrom': b['verse'],
    if (b['verse'] != null) 'verseTo': b['verse'],
    'quote': q,
    'occurrence': q.isEmpty
        ? 0
        : (() {
            var n = 0, i = -1;
            while ((i = text.indexOf(q, i + 1)) != -1 && i < at) n++;
            return n;
          })(),
    'prefix': text.substring(max(0, at - 80), max(0, at)),
    'suffix': text.substring(
      min(text.length, max(0, at) + q.length),
      min(text.length, max(0, at) + q.length + 80),
    ),
  };
}

StudyJson? studyLocate(StudyJson material, StudyJson target) {
  final mt = studyMap(material['target']);
  if (mt['kind'] != target['kind'] ||
      mt['id'] != target['id'] ||
      (target['edition'] != null && mt['edition'] != target['edition']) ||
      (target['statia'] ?? 0) != (mt['statia'] ?? 0) ||
      (target['kind'] == 'bible' && target['chapter'] != mt['chapter']))
    return null;
  final blocks = studyList(material['blocks']),
      quote = target['quote'] as String?;
  List<(int, int)> offsets(String text) {
    final out = <(int, int)>[];
    if (quote == null || quote.isEmpty) return out;
    var at = -1, ordinal = 0;
    while ((at = text.indexOf(quote, at + 1)) != -1) {
      if ((target['prefix'] == null ||
              text.substring(0, at).endsWith('${target['prefix']}')) &&
          (target['suffix'] == null ||
              text
                  .substring(at + quote.length)
                  .startsWith('${target['suffix']}')))
        out.add((at, ordinal));
      ordinal++;
    }
    return out;
  }

  if (target['endBlockId'] != null) {
    final from = blocks.indexWhere((b) => b['id'] == target['blockId']),
        to = blocks.indexWhere((b) => b['id'] == target['endBlockId']);
    if (from < 0 || to < from) return null;
    final body = blocks
        .sublist(from, to + 1)
        .map((b) => b['text'])
        .join('\n\n');
    if (quote != null && !body.contains(quote)) return null;
    if (target['sourceHash'] != material['sourceHash'] &&
        [
          blocks[from],
          blocks[to],
        ].any((b) => blocks.where((x) => x['hash'] == b['hash']).length > 1))
      return null;
    return blocks[from];
  }
  StudyJson? find(StudyJson b, {bool stable = false}) {
    if (quote == null || quote.isEmpty) return b;
    final hits = offsets('${b['text']}');
    if (hits.length == 1 ||
        stable &&
            target['occurrence'] != null &&
            hits.any((h) => h.$2 == target['occurrence']))
      return b;
    return null;
  }

  if (target['kind'] == 'bible' && target['verseFrom'] != null) {
    final block = blocks
        .where((b) => b['verse'] == target['verseFrom'])
        .firstOrNull;
    return block == null ? null : find(block, stable: true);
  }
  final block = blocks.where((b) => b['id'] == target['blockId']).firstOrNull;
  if (block != null) {
    if (target['sourceHash'] != material['sourceHash'] &&
        blocks.where((b) => b['hash'] == block['hash']).length > 1)
      return null;
    final result = find(block, stable: true);
    if (result != null) return result;
  }
  final hits = <StudyJson>[];
  for (final b in blocks) for (final _ in offsets('${b['text']}')) hits.add(b);
  return hits.length == 1 ? hits.single : null;
}

StudyJson studyRangeTarget(StudyJson material, String from, String to) {
  final blocks = studyList(material['blocks']),
      a = blocks.indexWhere((b) => b['id'] == from),
      b = blocks.indexWhere((b) => b['id'] == to);
  if (a < 0 || b < a)
    throw StateError(
      'Конец отрывка должен быть после его начала в том же источнике.',
    );
  final range = blocks.sublist(a, b + 1),
      quote = range.map((b) => b['text']).join('\n\n');
  if (quote.length > 20000)
    throw StateError(
      'Отрывок слишком большой. Сохраните его несколькими частями.',
    );
  return {
    ...studyMap(material['target']),
    'blockId': range.first['id'],
    'endBlockId': range.last['id'],
    'quote': quote,
    'sourceHash': material['sourceHash'],
    'prefix': '',
    'suffix': '',
    if (material['target']['kind'] == 'bible')
      'verseFrom': range.first['verse'],
    if (material['target']['kind'] == 'bible') 'verseTo': range.last['verse'],
  };
}

StudyJson studyUpsert(
  StudyJson state,
  String entity,
  StudyJson value, {
  bool deleted = false,
}) => {
  ...state,
  entity: [
    if (!deleted) value,
    ...studyList(state[entity]).where((v) => v['id'] != value['id']),
  ],
};
String studyHref(StudyJson t) =>
    'https://www.typikon.info/study?target=${Uri.encodeComponent(jsonEncode(t))}';
String studyMarkdown(StudyJson state) {
  final lines = <String>['# Моё чтение'];
  for (final c in studyList(state['collections'])) {
    lines.addAll(['## ${c['title']}', c['description'] ?? '']);
    for (final i in studyList(c['items'])) {
      lines.add(
        i['kind'] == 'section'
            ? '### ${i['title']}'
            : '- [${i['title']}](${i['target'] != null ? studyHref(studyMap(i['target'])) : ''})',
      );
      lines.add(i['comment'] ?? '');
    }
  }
  for (final r in studyList(state['records'])) {
    lines.addAll([
      '## ${r['kind'] == 'question' ? 'Вопрос' : 'Запись'}',
      '> ${r['originalQuote'] ?? studyMap(r['target'])['quote'] ?? ''}',
      r['note'] ?? '',
      'Источник выписки: ${studyHref(studyMap(r['originalTarget'] ?? r['target']))}',
      if (r['originalTarget'] != null &&
          jsonEncode(r['originalTarget']) != jsonEncode(r['target']))
        'Уточнённое место: ${studyHref(studyMap(r['target']))}',
    ]);
  }
  return lines.join('\n\n');
}
