import 'dart:convert';
import 'dart:math';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../store/rule_marks.dart' show dayKey;

typedef CircleJson = Map<String, dynamic>;
CircleJson circleCopy(CircleJson value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
CircleJson circleMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<CircleJson> circleList(dynamic value) => value is List
    ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : [];
String circleOperationId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

bool _zonesReady = false;
String circleCycleKey(DateTime now, String zone) {
  if (!_zonesReady) {
    tzdata.initializeTimeZones();
    _zonesReady = true;
  }
  final at = tz.TZDateTime.from(now, tz.getLocation(zone));
  return dayKey(DateTime(at.year, at.month, at.day - (at.hour < 15 ? 1 : 0)));
}

String circleShift(String date, int n) {
  final d = DateTime.parse(date);
  return dayKey(DateTime(d.year, d.month, d.day + n));
}

CircleJson initialCircleConfig({String zone = 'Europe/Moscow'}) => {
  'activeId': 'ordinary',
  'gender': 'm',
  'lang': 'cu_gr',
  'timeZone': zone,
  'reminders': {'morning': false, 'evening': false},
  'variants': [
    {
      'id': 'ordinary',
      'title': 'Обычное правило',
      'blocks': [
        {
          'id': 'evening_prayerbook',
          'title': 'Молитвы на сон грядущим',
          'kind': 'template',
          'key': 'na-son',
          'part': 'evening',
          'weekdays': [1, 2, 3, 4, 5, 6, 7],
        },
        {
          'id': 'morning_prayerbook',
          'title': 'Молитвы утренние',
          'kind': 'template',
          'key': 'utrennie',
          'part': 'morning',
          'weekdays': [1, 2, 3, 4, 5, 6, 7],
        },
        {
          'id': 'gospel',
          'title': 'Евангелие дня',
          'kind': 'day-readings',
          'key': 'gospel',
          'part': 'morning',
          'weekdays': [1, 2, 3, 4, 5, 6, 7],
        },
      ],
    },
  ],
};
CircleJson initialCircleState(CircleJson config) => {
  'revision': 0,
  'config': config,
  'cycles': <String, dynamic>{},
  'communionMarks': <String, dynamic>{},
  'cursors': <String, dynamic>{},
  'receipts': <String>[],
};
CircleJson ensureCircleCycle(CircleJson state, String key) {
  final pending = circleMap(state['pending']);
  final config =
      pending.isNotEmpty &&
          key.compareTo(pending['effectiveCycle'] as String) >= 0
      ? circleMap(pending['config'])
      : circleMap(state['config']);
  if (state['psalterCursor'] == null) {
    final variants = circleList(config['variants']);
    final ordered = [
      ...variants.where((v) => v['id'] == config['activeId']),
      ...variants.where((v) => v['id'] != config['activeId']),
    ];
    final previous = ordered
        .expand((v) => circleList(v['blocks']))
        .where((b) => b['kind'] == 'psalter')
        .map((b) => circleMap(state['cursors'])[b['id']])
        .whereType<int>()
        .where((n) => n >= 0 && n < 60)
        .firstOrNull;
    if (previous != null) state['psalterCursor'] = previous;
  }
  final cycles = circleMap(state['cycles']);
  state['cycles'] = cycles;
  cycles.putIfAbsent(key, () {
    final saved = circleMap(circleMap(state['history'])[key]);
    final savedConfig = circleMap(
      circleMap(state['historyConfigs'])[saved['configRef']],
    );
    return {
      'key': key,
      'config': circleCopy(savedConfig.isEmpty ? config : savedConfig),
      'overrides': circleMap(saved['overrides']),
      'marks': {
        ...circleMap(saved['marks']),
        ...circleMap(state['communionMarks']),
      },
      'counters': circleMap(saved['counters']),
      'cursors': circleCopy(
        saved['cursors'] is Map
            ? circleMap(saved['cursors'])
            : circleMap(state['cursors']),
      ),
      'advanced': List<String>.from(saved['advanced'] as List? ?? []),
      if (saved['bookmark'] != null) 'bookmark': saved['bookmark'],
    };
  });
  final keys = cycles.keys.where((k) => k != key).toList()..sort();
  for (final old in keys.take(max(0, keys.length - 39))) {
    final previous = circleMap(cycles[old]);
    final serialized = jsonEncode(previous['config']);
    var hash = 2166136261;
    for (final unit in serialized.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    final configurations = circleMap(state['historyConfigs']);
    var ref = '$hash', suffix = 0;
    while (configurations.containsKey(ref) &&
        jsonEncode(configurations[ref]) != serialized) {
      ref = '$hash-${++suffix}';
    }
    configurations[ref] = circleCopy(circleMap(previous['config']));
    state['historyConfigs'] = configurations;
    final history = circleMap(state['history']);
    history[old] = {
      'configRef': ref,
      for (final field in [
        'marks',
        'counters',
        'cursors',
        'advanced',
        'overrides',
        'bookmark',
      ])
        if (previous[field] != null) field: previous[field],

      'blocks': circleBlocks(previous)
          .map(
            (b) => {
              'id': b['id'],
              'title': b['title'],
              'part': b['part'],
              'done': circleMap(previous['marks'])[b['id']] == true,
            },
          )
          .toList(),
    };
    state['history'] = history;
    cycles.remove(old);
  }
  final communal = circleMap(state['communionMarks']);
  final preparation = circleMap(circleMap(cycles[key]['config'])['communion']);
  final occurrences = <String, int>{};
  final keysForPreparation = List<String>.from(
    preparation['customKeys'] as List? ?? [],
  );
  for (var i = 0; i < keysForPreparation.length; i++) {
    final template = keysForPreparation[i],
        ordinal = occurrences[keysForPreparation[i]] ?? 0;
    occurrences[template] = ordinal + 1;
    final old = 'communion:${preparation['date']}:custom:$i';
    final next = 'communion:${preparation['date']}:custom:$template:$ordinal';
    if (communal[old] is bool && !communal.containsKey(next))
      communal[next] = communal[old];
  }
  state['communionMarks'] = communal;
  (cycles[key]['marks'] as Map).addAll(circleMap(state['communionMarks']));
  final cycle = cycles[key] as CircleJson;
  final cursors = circleMap(state['cursors']);
  for (final block in circleBlocks(cycle)) {
    final id = block['id'] as String;
    if (block['kind'] != 'psalter' ||
        block['mode'] != 'continuous' ||
        (cycle['advanced'] as List).contains(id))
      continue;
    final assigned = circleMap(cycle['cursors']);
    final cursor = state['psalterCursor'] ?? cursors[id] ?? 0;
    if (assigned[id] != cursor) {
      assigned[id] = cursor;
      cycle['cursors'] = assigned;
      if ((cycle['bookmark'] as String? ?? '').startsWith('$id:'))
        cycle.remove('bookmark');
    }
  }
  return cycles[key] as CircleJson;
}

List<CircleJson> circleHistoryEntries(CircleJson state, {DateTime? now}) {
  final records = {
    ...circleMap(state['history']),
    for (final entry in circleMap(state['cycles']).entries)
      entry.key: {
        'blocks': circleBlocks(circleMap(entry.value))
            .map(
              (b) => {
                'id': b['id'],
                'title': b['title'],
                'part': b['part'],
                'done': circleMap(entry.value['marks'])[b['id']] == true,
              },
            )
            .toList(),
      },
  };
  final keys = records.keys.toList()..sort();
  final result = <CircleJson>[
    for (final entry in records.entries)
      {
        'date': entry.key,
        'blocks': circleMap(entry.value)['blocks'],
        'unopened': false,
      },
  ];
  var date = circleCycleKey(
    now ?? DateTime.now(),
    circleMap(state['config'])['timeZone'] as String,
  );
  for (
    var n = 0;
    keys.isNotEmpty && date.compareTo(keys.first) >= 0 && n < 90;
    n++, date = circleShift(date, -1)
  ) {
    if (!records.containsKey(date))
      result.add({'date': date, 'blocks': [], 'unopened': true});
  }
  result.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  return result;
}

List<CircleJson> circleBlocks(CircleJson cycle) {
  final config = circleMap(cycle['config']);
  final variants = circleList(config['variants']);
  final overrides = circleMap(cycle['overrides']);
  return ['evening', 'morning', 'day'].expand((part) {
    final id = overrides[part] ?? config['activeId'];
    final v = variants.where((v) => v['id'] == id).firstOrNull;
    final date = part == 'evening'
        ? cycle['key'] as String
        : circleShift(cycle['key'] as String, 1);
    final weekday = DateTime.parse(date).weekday;
    return circleList(v?['blocks']).where(
      (b) => b['part'] == part && (b['weekdays'] as List).contains(weekday),
    );
  }).toList();
}

List<CircleJson> circlePresets(CircleJson catalog) => [
  ...circleList(catalog['templates']).where((t) => t['status'] == 'verified'),
  {
    'id': 'psalter',
    'key': 'psaltir',
    'title': 'Псалтирь — в своём темпе',
    'status': 'verified',
    'kind': 'psalter',
  },
];

String _selectCirclePreset(CircleJson state, CircleJson cycle, CircleJson op) {
  final t = circleMap(op['template']);
  if (t['id'] != op['templateId'] ||
      t['status'] != 'verified' ||
      !['template', 'psalter'].contains(t['kind'] ?? 'template'))
    throw StateError('Последование ещё не проверено.');
  CircleJson make(String id) => {
    'id': id,
    'title': t['title'],
    'basedOn': t['id'],
    'blocks': [
      for (final part in ['evening', 'morning', 'day'])
        {
          'id': '$id:$part',
          'title': t['title'],
          'kind': t['kind'] ?? 'template',
          'key': t['key'],
          'templateId': t['id'],
          'part': part,
          'weekdays': [1, 2, 3, 4, 5, 6, 7],
          if (t['key'] == 'jesus') 'count': 100,
          if (t['kind'] == 'psalter') ...{
            'mode': 'continuous',
            'unit': 'kathisma',
            'departed': false,
          },
        },
    ],
  };
  final configs = <Map>[
    state['config'] as Map,
    cycle['config'] as Map,
    if (state['pending'] != null) (state['pending'] as Map)['config'] as Map,
  ];
  String signature(CircleJson v) => jsonEncode(
    circleList(v['blocks'])
        .map(
          (b) => [
            b['kind'],
            b['key'],
            b['part'],
            b['weekdays'],
            b['count'],
            b['durationMinutes'],
            b['placement'],
            b['mode'],
            b['unit'],
            b['departed'],
            b['schedule'],
          ],
        )
        .toList(),
  );
  var id = 'ready:${t['id']}';
  var variant = make(id);
  if (configs.any(
    (c) => circleList(
      c['variants'],
    ).any((v) => v['id'] == id && signature(v) != signature(variant)),
  )) {
    id += ':${op['id']}';
    variant = make(id);
  }
  for (final c in configs) {
    if (!circleList(c['variants']).any((v) => v['id'] == id)) {
      c['variants'] = [...circleList(c['variants']), circleCopy(variant)];
      validateCircleConfig(circleMap(c));
    }
  }
  if (t['kind'] == 'psalter') {
    final cursor = state['psalterCursor'] ?? op['startCursor'] ?? 0;
    if (cursor is! int || cursor < 0 || cursor > 59)
      throw StateError('Неверное место Псалтири.');
    final cursors = state['cursors'] as Map;
    for (final b in circleList(variant['blocks']))
      if (!cursors.containsKey(b['id'])) {
        cursors[b['id']] = cursor;
        state['psalterCursor'] ??= cursor;
        (cycle['cursors'] as Map)[b['id']] = cursors[b['id']];
      }
  }
  return id;
}

void _replaceCircleConfig(CircleJson cycle, CircleJson config) {
  String content(CircleJson b) => jsonEncode(
    [
      'kind',
      'key',
      'part',
      'templateId',
      'count',
      'durationMinutes',
      'placement',
      'mode',
      'unit',
      'schedule',
      'departed',
      'chapter',
      'verseFrom',
      'verseTo',
    ].map((key) => b[key]).toList(),
  );
  final old = <String, String>{
    for (final v in circleList(circleMap(cycle['config'])['variants']))
      for (final b in circleList(v['blocks'])) b['id'] as String: content(b),
  };
  final compatible = <String>{
    for (final v in circleList(config['variants']))
      for (final b in circleList(v['blocks']))
        if (old[b['id']] == content(b)) b['id'] as String,
  };
  (cycle['marks'] as Map).removeWhere(
    (key, value) =>
        !key.toString().startsWith('communion:') && !compatible.contains(key),
  );
  (cycle['counters'] as Map).removeWhere(
    (key, value) => !compatible.contains(key),
  );
  cycle['config'] = circleCopy(config);
  cycle['overrides'] = <String, dynamic>{};
}

CircleJson applyCircleOperation(
  CircleJson original,
  CircleJson op, {
  DateTime? now,
}) {
  if ((original['receipts'] as List).contains(op['id'])) return original;
  if (op['revision'] != original['revision'])
    throw StateError('Круг изменился на другом устройстве.');
  final state = circleCopy(original);
  final cycle = ensureCircleCycle(state, op['cycle'] as String);
  final marks = circleMap(cycle['marks']);
  cycle['marks'] = marks;
  final sharedMarks = circleMap(state['communionMarks']);
  sharedMarks.removeWhere(
    (key, value) => RegExp(r'^communion:.*:custom:\d+$').hasMatch(key),
  );
  state['communionMarks'] = sharedMarks;
  switch (op['action']) {
    case 'config':
      final c = circleCopy(circleMap(op['config']));
      validateCircleConfig(c);
      final cursors = circleMap(state['cursors']);
      state['cursors'] = cursors;
      for (final variant in circleList(c['variants'])) {
        for (final block in circleList(variant['blocks'])) {
          if (block['kind'] == 'psalter' && !cursors.containsKey(block['id'])) {
            final inherited =
                state['psalterCursor'] ?? state['legacyPsalterCursor'] ?? 0;
            cursors[block['id']] = inherited;
            (cycle['cursors'] as Map)[block['id']] = cursors[block['id']];
          }
        }
      }
      if (op['applyToday'] == true) {
        final todayKey = circleCycleKey(
          now ?? DateTime.now(),
          circleMap(state['config'])['timeZone'] as String,
        );
        final target = ensureCircleCycle(state, todayKey);
        _replaceCircleConfig(target, c);
        state['config'] = c;
        state.remove('pending');
      } else {
        state['pending'] = {
          'effectiveCycle': circleShift(
            circleCycleKey(
              now ?? DateTime.now(),
              circleMap(state['config'])['timeZone'] as String,
            ),
            1,
          ),
          'config': c,
        };
      }
      final effective = op['applyToday'] == true
          ? circleCycleKey(
              now ?? DateTime.now(),
              circleMap(state['config'])['timeZone'] as String,
            )
          : circleMap(state['pending'])['effectiveCycle'] as String;
      for (final entry in circleMap(state['cycles']).entries) {
        if (entry.key.compareTo(effective) >= 0) {
          _replaceCircleConfig(entry.value as CircleJson, c);
        }
      }
      for (final date in circleMap(state['history']).keys.toList()) {
        if (date.compareTo(effective) >= 0) {
          _replaceCircleConfig(ensureCircleCycle(state, date), c);
        }
      }
    case 'override':
      final id = op['templateId'] != null
          ? _selectCirclePreset(state, cycle, op)
          : op['variantId'];
      (cycle['overrides'] as Map)[op['part']] = id;
    case 'bookmark':
      cycle['bookmark'] = op['rowId'];
    case 'counter':
      (cycle['counters'] as Map)[op['blockId']] = op['count'];
    case 'communion-plan':
      final plan = op['plan'];
      final config = circleMap(state['config']);
      config['communion'] = plan;
      state['config'] = config;
      final pending = circleMap(state['pending']);
      if (pending.isNotEmpty) {
        final pc = circleMap(pending['config']);
        pc['communion'] = plan;
        pending['config'] = pc;
        state['pending'] = pending;
      }
      final today = circleCycleKey(
        now ?? DateTime.now(),
        config['timeZone'] as String,
      );
      final target = ensureCircleCycle(state, today);
      (target['config'] as Map)['communion'] = plan;
      for (final entry in circleMap(state['cycles']).entries) {
        if (entry.key.compareTo(today) > 0) {
          (entry.value['config'] as Map)['communion'] = plan;
        }
      }
    case 'communion-mark':
      final date = circleMap(circleMap(cycle['config'])['communion'])['date'];
      if (date != null) {
        final key = 'communion:$date:${op['blockId']}';
        final shared = circleMap(state['communionMarks']);
        shared[key] = op['done'];
        state['communionMarks'] = shared;
        for (final snapshot in circleMap(state['cycles']).values) {
          (snapshot['marks'] as Map)[key] = op['done'];
        }
      }
    case 'mark':
      final b = circleBlocks(
        cycle,
      ).where((b) => b['id'] == op['blockId']).firstOrNull;
      if (b == null) throw StateError('Блока нет в этом дне.');
      if (b['kind'] == 'psalter' &&
          b['mode'] == 'continuous' &&
          op['expectedCursor'] != null &&
          op['expectedCursor'] != (circleMap(cycle['cursors'])[b['id']] ?? 0))
        throw StateError(
          'Место Псалтири изменилось. Обновите чтение перед отметкой.',
        );
      marks[b['id'] as String] = op['done'];
      final advanced = List<String>.from(cycle['advanced'] as List);
      cycle['advanced'] = advanced;
      if (op['done'] == true &&
          b['kind'] == 'psalter' &&
          b['mode'] == 'continuous' &&
          !advanced.contains(b['id'])) {
        final id = b['id'] as String;
        final cursors = circleMap(state['cursors']);
        state['cursors'] = cursors;
        final assigned = circleMap(cycle['cursors'])[id] as int? ?? 0;
        if ((state['psalterCursor'] ?? cursors[id] ?? 0) != assigned)
          throw StateError('Место Псалтири изменилось. Обновите круг.');
        final next =
            (b['unit'] == 'statia' ? assigned + 1 : (assigned ~/ 3 + 1) * 3) %
            60;
        state['psalterCursor'] = next;
        final configs = [
          circleMap(state['config']),
          circleMap(circleMap(state['pending'])['config']),
          ...circleMap(
            state['cycles'],
          ).values.map((c) => circleMap(c['config'])),
        ];
        for (final config in configs)
          for (final variant in circleList(config['variants']))
            for (final block in circleList(variant['blocks']))
              if (block['kind'] == 'psalter') cursors[block['id']] = next;
        advanced.add(id);
        for (final date in circleMap(state['cycles']).keys.toList()) {
          ensureCircleCycle(state, date);
        }
      }
    case 'next':
      final b = circleBlocks(
        cycle,
      ).where((b) => b['id'] == op['blockId']).firstOrNull;
      if (b == null ||
          b['kind'] != 'psalter' ||
          b['mode'] != 'continuous' ||
          marks[b['id']] != true ||
          !(cycle['advanced'] as List).contains(b['id']))
        throw StateError('Сначала отметьте текущее чтение Псалтири.');
      final id = b['id'];
      if (op['expectedCursor'] != (circleMap(cycle['cursors'])[id] ?? 0))
        throw StateError('Место Псалтири изменилось. Обновите круг.');
      marks[id] = false;
      (cycle['advanced'] as List).remove(id);
      (cycle['cursors'] as Map)[id] =
          state['psalterCursor'] ?? circleMap(state['cursors'])[id] ?? 0;
      if ((cycle['bookmark'] as String? ?? '').startsWith('$id:'))
        cycle.remove('bookmark');
    default:
      throw StateError('Неизвестная операция.');
  }
  state['revision'] = (state['revision'] as int) + 1;
  final receipts = [
    ...List<String>.from(state['receipts'] as List),
    op['id'] as String,
  ];
  state['receipts'] = receipts.skip(max(0, receipts.length - 2000)).toList();
  return state;
}

void validateCircleConfig(CircleJson c) {
  if (c['readerFont'] != null &&
      !['civil', 'church'].contains(c['readerFont'])) {
    throw const FormatException('Выберите шрифт читателя.');
  }
  final variants = circleList(c['variants']);
  if (variants.isEmpty ||
      variants.length > 32 ||
      !variants.any((v) => v['id'] == c['activeId']))
    throw const FormatException('Выберите активный вариант правила.');
  if (!['m', 'f'].contains(c['gender']) || !['cu', 'cu_gr'].contains(c['lang']))
    throw const FormatException('Проверьте язык и род молитв.');
  if (c['timeZone'] is! String)
    throw const FormatException('Выберите часовой пояс.');
  circleCycleKey(DateTime.now(), c['timeZone'] as String);
  final ids = <String>{};
  for (final variant in variants) {
    if (variant['title'] is! String ||
        (variant['title'] as String).trim().isEmpty ||
        (variant['title'] as String).length > 120)
      throw const FormatException('Укажите название варианта.');
    final blocks = circleList(variant['blocks']);
    if (blocks.length > 60)
      throw const FormatException('Не больше 60 чтений в варианте.');
    for (final b in blocks) {
      final id = b['id'];
      if (id is! String || !ids.add(id))
        throw const FormatException('Повторяющееся место чтения.');
      final days = b['weekdays'];
      if (days is! List ||
          days.isEmpty ||
          days.any((d) => d is! int || d < 1 || d > 7) ||
          days.toSet().length != days.length)
        throw const FormatException('Выберите дни недели.');
      final duration = b['durationMinutes'];
      if (duration != null &&
          (duration is! int || duration < 1 || duration > 240))
        throw const FormatException('Продолжительность от 1 до 240 минут.');
      if (b['placement'] != null &&
          !['standalone', 'embedded'].contains(b['placement']))
        throw const FormatException('Выберите способ чтения.');
      final count = b['count'];
      if (count != null && (count is! int || count < 1 || count > 10000))
        throw const FormatException('Число повторений: от 1 до 10000.');
      if (b['kind'] == 'scripture') {
        final chapter = b['chapter'];
        final first = b['verseFrom'];
        final last = b['verseTo'];
        if (chapter is! int ||
            chapter < 1 ||
            chapter > 150 ||
            first != null && (first is! int || first < 1 || first > 176) ||
            last != null &&
                (last is! int ||
                    last < 1 ||
                    last > 176 ||
                    (first is int && last < first)))
          throw const FormatException('Проверьте главу и стихи.');
      }
      if (b['kind'] == 'psalter') {
        if (!['continuous', 'scheduled', 'liturgical'].contains(b['mode']) ||
            !['statia', 'kathisma'].contains(b['unit']))
          throw const FormatException('Выберите способ чтения Псалтири.');
        if (b['mode'] == 'scheduled')
          for (final entry in circleMap(b['schedule']).entries) {
            final day = int.tryParse(entry.key);
            if (day == null ||
                day < 1 ||
                day > 7 ||
                entry.value is! List ||
                (entry.value as List).any((n) => n is! int || n < 1 || n > 20))
              throw const FormatException('Кафизмы в расписании: от 1 до 20.');
          }
      }
    }
  }
  final plan = circleMap(c['communion']);
  if (plan.isNotEmpty) {
    final date = DateTime.tryParse(plan['date'] as String? ?? '');
    final days = plan['days'];
    if (date == null ||
        dayKey(date) != plan['date'] ||
        days is! int ||
        days < 0 ||
        days > 40)
      throw const FormatException('Проверьте дату и длительность подготовки.');
  }
}

CircleJson circleProgress(CircleJson cycle) => {
  for (final key in ['marks', 'counters', 'cursors', 'overrides', 'bookmark'])
    if (cycle.containsKey(key)) key: cycle[key],
};
