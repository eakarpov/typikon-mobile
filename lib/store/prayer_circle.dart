import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/v2/request.dart';
import '../apiMapper/session.dart';
import '../apiMapper/v2/errors.dart';
import '../domain/prayer_circle.dart';
import '../utils/push.dart' show deviceTimeZone;
import '../utils/rule_reminders.dart';
import 'rule_marks.dart';
import 'rule_cycle.dart';
import 'communion_plan.dart';
import 'psalter_serial_bookmark.dart';
import '../domain/psalter.dart';
import 'store.dart';
import 'reading_progress.dart';

Future<void> _clearLegacyCircleState(SharedPreferences p) async {
  await clearCommunionPlan();
  for (final key
      in p
          .getKeys()
          .where(
            (k) =>
                k.startsWith('communion_done:') ||
                k.startsWith('communion_active_item_ids:') ||
                k.startsWith('rule_done:'),
          )
          .toList()) {
    await p.remove(key);
  }
  for (final key in [
    ruleGenderKey,
    'rule_morning_horologion',
    'rule_evening_horologion',
  ]) {
    await p.remove(key);
  }
  await setRuleReminder(ruleRemindMorningKey, false);
  await setRuleReminder(ruleRemindEveningKey, false);
}

Future<void> clearPrivatePrayerCircleCache() async {
  final p = await SharedPreferences.getInstance();
  for (final key
      in p
          .getKeys()
          .where(
            (k) =>
                k.startsWith('prayer-circle:user:') && k.contains(':preview:'),
          )
          .toList()) {
    await p.remove(key);
  }
  // The previous screens read these global preferences before a circle opens.
  // Once mirrored from a private circle they must not survive account logout.
  final legacyOwner = p.getString('prayer-circle:legacy-owner');
  if (legacyOwner != null && legacyOwner != 'guest') {
    await _clearLegacyCircleState(p);
    await p.remove('prayer-circle:legacy-owner');
  }
}

class PrayerCircleRepository {
  final String? userId;
  final String? Function() owner;
  PrayerCircleRepository(this.userId, {String? Function()? owner})
    : owner = owner ?? (() => appStore?.state.auth.userId);
  String get scope => userId == null ? 'guest' : 'user:$userId';
  String get storageKey => 'prayer-circle:$scope';
  void _checkOwner() {
    if (owner() != userId)
      throw StateError('Вход изменился. Откройте круг заново.');
  }

  Future<CircleJson> _request(
    String method,
    String path, {
    CircleJson? body,
    bool personal = false,
  }) async {
    _checkOwner();
    if (personal && body != null) body = {...body, 'expectedUserId': userId};
    final response = personal && userId != null
        ? await withSession(
            () => v2Send(method, v2Uri('/prayer-circle$path'), body: body),
          )
        : await v2Send(method, v2Uri('/prayer-circle$path'), body: body);
    _checkOwner();
    if (response.statusCode != 200)
      throwV2Error(response, 'Не удалось загрузить личный круг');
    return circleMap(jsonDecode(response.body));
  }

  Future<CircleJson> catalog() async {
    final p = await SharedPreferences.getInstance();
    try {
      final c = await _request('GET', '/catalog');
      await p.setString('prayer-circle:catalog', jsonEncode(c));
      return c;
    } catch (_) {
      final raw = p.getString('prayer-circle:catalog');
      if (raw != null) return circleMap(jsonDecode(raw));
      rethrow;
    }
  }

  Future<CircleJson> migrateLegacy() async {
    final config = initialCircleConfig(zone: await deviceTimeZone());
    config['gender'] = await ruleGender();
    final variants = circleList(config['variants']);
    final blocks = circleList(variants.first['blocks']);
    final morning = await ruleUsesHorologion(true),
        evening = await ruleUsesHorologion(false);
    if (morning)
      blocks[1] = {
        'id': 'morning_horologion',
        'title': 'Утреннее правило Часослова',
        'kind': 'template',
        'key': 'horologion',
        'part': 'morning',
        'weekdays': [1, 2, 3, 4, 5, 6, 7],
      };
    if (evening)
      blocks[0] = {
        'id': 'compline',
        'title': 'Повечерие с каноном',
        'kind': 'template',
        'key': 'horologion',
        'part': 'evening',
        'weekdays': [1, 2, 3, 4, 5, 6, 7],
      };
    final p = await SharedPreferences.getInstance();
    config['reminders'] = {
      'morning': p.getBool('rule_remind_morning') ?? false,
      'evening': p.getBool('rule_remind_evening') ?? false,
    };
    variants.first['blocks'] = blocks;
    config['variants'] = variants;
    final plan = await getCommunionPlan();
    if (plan != null)
      config['communion'] = {
        'date': dayKey(plan.date),
        'days': plan.preparationDays,
      };
    final s = initialCircleState(config);
    final cycle = ensureCircleCycle(
      s,
      circleCycleKey(DateTime.now(), config['timeZone'] as String),
    );
    final old = await ruleCycleMarks(RuleCycle.at(DateTime.now()));
    cycle['marks'] = {
      ...old,
      if (morning)
        'morning_horologion':
            old['morning_horologion'] == true && old['midnight'] == true,
    };
    if (plan != null) {
      await migrateCommunionMarks(dayKey(plan.date));
      final marks = await marksWithPrefix(
        'communion_done:${dayKey(plan.date)}:',
      );
      for (final e in marks.entries) {
        (cycle['marks']
            as Map)['communion:${dayKey(plan.date)}:${e.key == 'day:blagodarstvennye' ? 'thanksgiving' : e.key}'] = e
            .value;
      }
    }
    s['communionMarks'] = Map<String, dynamic>.fromEntries(
      circleMap(
        cycle['marks'],
      ).entries.where((e) => e.key.startsWith('communion:')),
    );
    // Keep the verse-accurate legacy bookmark independently of the circle's mode.
    final bookmark = await getPsalterSerialBookmark();
    if (bookmark != null) {
      final n = kathismaRanges.entries
          .where(
            (e) =>
                bookmark.chapter >= e.value.$1 &&
                bookmark.chapter <= e.value.$2,
          )
          .firstOrNull
          ?.key;
      if (n != null) {
        var statia = 0;
        final parts = kathismaStatii(n);
        for (var i = 0; i < parts.length; i++) {
          final part = parts[i];
          if (bookmark.chapter >= part.firstPsalm &&
              bookmark.chapter <= part.lastPsalm &&
              (part.firstVerse == null ||
                  bookmark.verse >= part.firstVerse! &&
                      bookmark.verse <= part.lastVerse!)) {
            statia = i;
            break;
          }
        }
        s['legacyPsalterCursor'] = (n - 1) * 3 + statia;
        s['legacyPsalterBookmark'] = {
          'chapter': bookmark.chapter,
          'verse': bookmark.verse,
        };
      }
    }
    return s;
  }

  Future<CircleJson> load() async {
    final p = await SharedPreferences.getInstance();
    _checkOwner();
    final legacyOwner = p.getString('prayer-circle:legacy-owner');
    if (legacyOwner == null && p.getString('prayer-circle:guest') == null) {
      final privateExists = p.getKeys().any(
        (k) => k.startsWith('prayer-circle:user:') && !k.contains(':preview:'),
      );
      await p.setString(
        'prayer-circle:guest',
        jsonEncode({
          'state': privateExists
              ? initialCircleState(initialCircleConfig())
              : await migrateLegacy(),
          'queue': [],
          'hasRemote': false,
        }),
      );
    }
    if (legacyOwner != null && legacyOwner != scope) {
      await _clearLegacyCircleState(p);
    }
    final saved = p.getString(storageKey);
    CircleJson? local;
    if (saved != null) {
      try {
        local = circleMap(jsonDecode(saved));
      } catch (_) {}
    }
    if (userId != null) {
      try {
        final remote = await _request('GET', '', personal: true);
        if (remote['userId'] != userId) throw StateError('Аккаунт изменился.');
        final state = circleMap(remote['state']);
        if (state.isNotEmpty &&
            (local == null || circleList(local['queue']).isEmpty)) {
          local = {'state': state, 'queue': [], 'hasRemote': true};
          await save(local);
        } else if (local != null) {
          local['hasRemote'] = state.isNotEmpty;
        }
      } on SessionExpiredException {
        rethrow;
      } catch (_) {
        _checkOwner();
        if (local == null) rethrow;
      }
    }
    if (local == null || circleMap(local['state']).isEmpty) {
      final guestRaw = p.getString('prayer-circle:guest');
      final guest = guestRaw == null
          ? await migrateLegacy()
          : circleMap(circleMap(jsonDecode(guestRaw))['state']);
      local = {'state': guest, 'queue': [], 'hasRemote': false};
      await save(local);
    }
    final active = ensureCircleCycle(
      circleCopy(circleMap(local['state'])),
      circleCycleKey(
        DateTime.now(),
        circleMap(circleMap(local['state'])['config'])['timeZone'] as String,
      ),
    );
    final config = circleMap(active['config']);
    await setRuleGender(config['gender'] as String);
    final reminders = circleMap(config['reminders']);
    await setRuleReminder(ruleRemindMorningKey, reminders['morning'] == true);
    await setRuleReminder(ruleRemindEveningKey, reminders['evening'] == true);
    final preparation = circleMap(config['communion']);
    if (preparation.isNotEmpty) {
      final selected = DateTime.parse(preparation['date'] as String);
      final days = preparation['days'] as int;
      final old = await getCommunionPlan();
      if (old == null ||
          dayKey(old.date) != dayKey(selected) ||
          old.preparationDays != days)
        await saveCommunionPlan(
          CommunionPlan(
            selected.subtract(Duration(days: days)),
            selected,
            preparationDays: days,
          ),
        );
    } else {
      await clearCommunionPlan();
    }
    await p.setString('prayer-circle:legacy-owner', scope);
    return local;
  }

  Future<void> save(CircleJson document) async {
    _checkOwner();
    await (await SharedPreferences.getInstance()).setString(
      storageKey,
      jsonEncode(document),
    );
  }

  Future<CircleJson> operation(
    CircleJson doc,
    String cycle,
    String action,
    CircleJson values,
  ) async {
    final s = circleMap(doc['state']);
    final op = <String, dynamic>{
      'id': circleOperationId(),
      'revision': s['revision'],
      'cycle': cycle,
      'action': action,
      ...values,
    };
    final next = {
      'state': applyCircleOperation(s, op),
      'queue': userId == null ? [] : [...circleList(doc['queue']), op],
      'hasRemote': doc['hasRemote'] == true,
    };
    await save(next);
    if (action == 'mark' || action == 'bookmark') {
      final at = ensureCircleCycle(circleCopy(circleMap(next['state'])), cycle);
      final blocks = circleBlocks(at);
      final marks = circleMap(at['marks']);
      final done = blocks.where((b) => marks[b['id']] == true).length;
      await saveReadingProgress(
        'rule:cycle:$cycle',
        blocks.isEmpty
            ? 0
            : (done == 0 && at['bookmark'] != null
                  ? 0.01
                  : done / blocks.length),
        name: 'Мой круг',
      );
    }
    if (action == 'communion-mark') {
      final current = ensureCircleCycle(
        circleCopy(circleMap(next['state'])),
        cycle,
      );
      final chosen = circleMap(
        circleMap(current['config'])['communion'],
      )['date'];
      if (chosen is String)
        await setCommunionItemDone(
          chosen,
          values['blockId'] as String,
          values['done'] == true,
        );
    }
    return next;
  }

  Future<CircleJson> sync(CircleJson doc) async {
    if (userId == null || doc['hasRemote'] != true) return doc;
    final response = await _request('GET', '', personal: true);
    if (response['userId'] != userId) throw StateError('Аккаунт изменился.');
    var state = circleMap(response['state']);
    if (state.isEmpty) throw StateError('Сначала сохраните круг в аккаунте.');
    for (final op in circleList(doc['queue'])) {
      if ((state['receipts'] as List).contains(op['id'])) continue;
      if (state['revision'] != op['revision'])
        throw StateError(
          'Круг изменился на другом устройстве. Местные изменения сохранены. Загрузите аккаунт или перенесите местный состав отдельным вариантом.',
        );
      final result = await _request('PATCH', '', body: op, personal: true);
      if (result['userId'] != userId) throw StateError('Аккаунт изменился.');
      state = circleMap(result['state']);
    }
    final result = {'state': state, 'queue': [], 'hasRemote': true};
    await save(result);
    return result;
  }

  Future<CircleJson> transfer(
    CircleJson doc,
    String cycle, {
    bool append = false,
  }) async {
    if (userId == null) throw StateError('Войдите в аккаунт.');
    final config = circleCopy(circleMap(circleMap(doc['state'])['config']));
    if (append) {
      final response = await _request('GET', '', personal: true);
      final remote = circleMap(response['state']);
      if (remote.isEmpty) throw StateError('В аккаунте нет круга.');
      final imported = circleList(config['variants'])
          .map(
            (v) => {
              ...v,
              'id': circleOperationId(),
              'title': '${v['title']} (с устройства)',
              'blocks': circleList(
                v['blocks'],
              ).map((b) => {...b, 'id': circleOperationId()}).toList(),
            },
          )
          .toList();
      final c = circleCopy(circleMap(remote['config']));
      c['variants'] = [...circleList(c['variants']), ...imported];
      final result = await _request(
        'PATCH',
        '',
        personal: true,
        body: {
          'id': circleOperationId(),
          'revision': remote['revision'],
          'cycle': cycle,
          'action': 'config',
          'config': c,
          'applyToday': true,
        },
      );
      final next = {'state': result['state'], 'queue': [], 'hasRemote': true};
      await save(next);
      return next;
    }
    final result = await _request(
      'POST',
      '',
      personal: true,
      body: {
        'config': config,
        'cycle': cycle,
        'cursors': circleMap(circleMap(doc['state'])['cursors']),
        if (circleMap(doc['state'])['psalterCursor'] != null)
          'psalterCursor': circleMap(doc['state'])['psalterCursor'],
        'progress': circleProgress(
          ensureCircleCycle(circleCopy(circleMap(doc['state'])), cycle),
        ),
      },
    );
    final next = {'state': result['state'], 'queue': [], 'hasRemote': true};
    await save(next);
    return next;
  }

  Future<CircleJson> preview(
    CircleJson state,
    String key, {
    String cacheTag = 'rule',
  }) async {
    final c = ensureCircleCycle(circleCopy(state), key);
    final signature = jsonEncode({
      'config': c['config'],
      'overrides': c['overrides'],
      'cursors': c['cursors'],
    });
    final p = await SharedPreferences.getInstance();
    final cache = '$storageKey:preview:$cacheTag:$key';
    try {
      final value = await _request(
        'POST',
        '/preview',
        personal: userId != null,
        body: {
          'expectedUserId': userId,
          'config': c['config'],
          'cycle': key,
          'progress': circleProgress(c),
        },
      );
      final communion = circleMap(value['communion']);
      _checkOwner();
      if (communion.isNotEmpty) {
        await p.setStringList(
          'communion_active_item_ids:${communion['date']}',
          circleList(communion['sections'])
              .where((s) => s['id'] != 'thanksgiving')
              .map((s) => s['id'] as String)
              .toList(),
        );
      }
      final oldRaw = p.getString(cache);
      var old = <String, dynamic>{};
      try {
        if (oldRaw != null) old = circleMap(jsonDecode(oldRaw));
      } catch (_) {}
      if (value['complete'] == true ||
          old['signature'] != signature ||
          circleMap(old['value'])['complete'] != true) {
        await p.setString(
          cache,
          jsonEncode({'signature': signature, 'value': value}),
        );
      }
      if (owner() != userId) {
        await p.remove(cache);
        _checkOwner();
      }
      return value;
    } catch (_) {
      _checkOwner();
      final raw = p.getString(cache);
      if (raw != null) {
        final cached = circleMap(jsonDecode(raw));
        if (cached['signature'] == signature)
          return {...circleMap(cached['value']), 'offline': true};
      }
      rethrow;
    }
  }
}

/// Keep the existing preparation screen connected to the same personal circle.
Future<void> updateCirclePreparation(CommunionPlan plan) async {
  final repo = PrayerCircleRepository(appStore?.state.auth.userId);
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(repo.storageKey);
  if (raw == null) return;
  final document = circleMap(jsonDecode(raw));
  final state = circleMap(document['state']);
  final key = circleCycleKey(
    DateTime.now(),
    circleMap(state['config'])['timeZone'] as String,
  );
  final existing = circleMap(
    circleMap(ensureCircleCycle(circleCopy(state), key)['config'])['communion'],
  );
  if (existing['date'] == dayKey(plan.date) &&
      existing['days'] == plan.preparationDays)
    return;
  final next = await repo.operation(document, key, 'communion-plan', {
    'plan': {'date': dayKey(plan.date), 'days': plan.preparationDays},
  });
  try {
    await repo.sync(next);
  } catch (_) {
    /* The operation stays in the account's offline queue. */
  }
}

Future<void> updateCirclePreparationMark(
  String date,
  String id,
  bool done,
) async {
  final repo = PrayerCircleRepository(appStore?.state.auth.userId);
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(repo.storageKey);
  if (raw == null) return;
  final doc = circleMap(jsonDecode(raw));
  final state = circleMap(doc['state']);
  final key = circleCycleKey(
    DateTime.now(),
    circleMap(state['config'])['timeZone'] as String,
  );
  final cycle = ensureCircleCycle(circleCopy(state), key);
  if (circleMap(circleMap(cycle['config'])['communion'])['date'] != date)
    return;
  final next = await repo.operation(doc, key, 'communion-mark', {
    'blockId': id == 'day:blagodarstvennye' ? 'thanksgiving' : id,
    'done': done,
  });
  try {
    await repo.sync(next);
  } catch (_) {
    /* Retry from the circle screen. */
  }
}
