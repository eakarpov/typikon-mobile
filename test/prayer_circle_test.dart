import 'package:typikon/store/rule_marks.dart' show dayKey;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typikon/domain/prayer_circle.dart';
import 'package:typikon/store/prayer_circle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 1, 13);
  CircleJson op(int revision, String action, CircleJson values) => {
    'id': 'op-$revision',
    'revision': revision,
    'cycle': '2026-11-01',
    'action': action,
    ...values,
  };
  test('existing Psalter cursor seeds the shared bookmark', () {
    final c = initialCircleConfig();
    (c['variants'] as List).first['blocks'] = [
      {
        'id': 'oldps',
        'title': 'Псалтирь',
        'kind': 'psalter',
        'key': 'psaltir',
        'part': 'evening',
        'weekdays': [1, 2, 3, 4, 5, 6, 7],
        'mode': 'scheduled',
        'unit': 'kathisma',
        'schedule': {
          '7': [1],
        },
      },
    ];
    final s = initialCircleState(c);
    (s['cursors'] as Map)['oldps'] = 49;
    ensureCircleCycle(s, '2026-11-01');
    expect(s['psalterCursor'], 49);
  });
  test(
    'continuous Psalter shares position and can continue within a cycle',
    () {
      final c = initialCircleConfig();
      (c['variants'] as List).first['blocks'] = [
        for (final part in ['evening', 'morning'])
          {
            'id': 'ps-$part',
            'title': 'Псалтирь',
            'kind': 'psalter',
            'key': 'psaltir',
            'part': part,
            'weekdays': [1, 2, 3, 4, 5, 6, 7],
            'mode': 'continuous',
            'unit': 'statia',
          },
      ];
      var s = initialCircleState(c);
      s = applyCircleOperation(
        s,
        op(0, 'mark', {
          'blockId': 'ps-evening',
          'done': true,
          'expectedCursor': 0,
        }),
        now: now,
      );
      expect(s['psalterCursor'], 1);
      expect(
        circleMap(ensureCircleCycle(s, '2026-11-01')['cursors'])['ps-morning'],
        1,
      );
      expect(
        () => applyCircleOperation(
          s,
          op(1, 'mark', {
            'blockId': 'ps-morning',
            'done': true,
            'expectedCursor': 0,
          }),
          now: now,
        ),
        throwsStateError,
      );
      final next = op(1, 'next', {
        'blockId': 'ps-evening',
        'expectedCursor': 0,
      });
      s = applyCircleOperation(s, next, now: now);
      expect(applyCircleOperation(s, next, now: now), s);
      s = applyCircleOperation(
        s,
        op(2, 'mark', {
          'blockId': 'ps-evening',
          'done': true,
          'expectedCursor': 1,
        }),
        now: now,
      );
      expect(s['psalterCursor'], 2);
    },
  );
  test('applying today preserves only compatible completion marks', () {
    var s = initialCircleState(initialCircleConfig());
    s = applyCircleOperation(
      s,
      op(0, 'mark', {'blockId': 'morning_prayerbook', 'done': true}),
      now: now,
    );
    s = applyCircleOperation(
      s,
      op(1, 'mark', {'blockId': 'evening_prayerbook', 'done': true}),
      now: now,
    );
    final config = circleCopy(circleMap(s['config']));
    ((config['variants'] as List).first['blocks'] as List).first['key'] =
        'serafim';
    s = applyCircleOperation(
      s,
      op(2, 'config', {'config': config, 'applyToday': true}),
      now: now,
    );
    final marks = circleMap(ensureCircleCycle(s, '2026-11-01')['marks']);
    expect(marks['morning_prayerbook'], true);
    expect(marks['evening_prayerbook'], isNull);
  });
  test(
    'ready choices include Horologion and preserve the default and existing marks',
    () {
      final catalog = {
        'templates': [
          {
            'id': 'horologion',
            'key': 'horologion',
            'title': 'Часослов',
            'status': 'verified',
          },
          {
            'id': 'old',
            'key': 'old',
            'title': '1636',
            'status': 'needs_collation',
          },
        ],
      };
      expect(circlePresets(catalog).map((t) => t['id']), [
        'horologion',
        'psalter',
      ]);
      var s = initialCircleState(initialCircleConfig());
      s = applyCircleOperation(
        s,
        op(0, 'mark', {'blockId': 'evening_prayerbook', 'done': true}),
        now: now,
      );
      final t = circlePresets(catalog).first;
      final choice = op(1, 'override', {
        'part': 'morning',
        'templateId': t['id'],
        'template': t,
      });
      s = applyCircleOperation(s, choice, now: now);
      final cycle = ensureCircleCycle(s, '2026-11-01');
      expect(circleMap(s['config'])['activeId'], 'ordinary');
      expect(circleMap(cycle['marks'])['evening_prayerbook'], true);
      expect(
        circleBlocks(cycle).firstWhere((b) => b['part'] == 'morning')['key'],
        'horologion',
      );
      expect(
        circleBlocks(cycle).firstWhere((b) => b['part'] == 'evening')['key'],
        'na-son',
      );
      expect(applyCircleOperation(s, choice, now: now), s);
    },
  );
  test('15:00 and midnight use the configured time zone', () {
    expect(
      circleCycleKey(DateTime.utc(2026, 11, 1, 11, 59), 'Europe/Moscow'),
      '2026-10-31',
    );
    expect(
      circleCycleKey(DateTime.utc(2026, 11, 1, 12), 'Europe/Moscow'),
      '2026-11-01',
    );
    expect(
      circleCycleKey(DateTime.utc(2026, 11, 1, 22), 'Europe/Moscow'),
      '2026-11-01',
    );
  });
  test('a future preview does not change current composition', () {
    var s = initialCircleState(initialCircleConfig());
    ensureCircleCycle(s, '2026-11-02');
    final c = initialCircleConfig();
    (c['variants'] as List).first['title'] = 'Новое';
    s = applyCircleOperation(s, op(0, 'config', {'config': c}), now: now);
    expect(
      circleList(
        circleMap(ensureCircleCycle(s, '2026-11-01')['config'])['variants'],
      ).first['title'],
      'Обычное правило',
    );
    expect(
      circleList(
        circleMap(ensureCircleCycle(s, '2026-11-02')['config'])['variants'],
      ).first['title'],
      'Новое',
    );
  });
  test('repeated delivery and unchecking do not advance Psalter again', () {
    final c = initialCircleConfig();
    ((c['variants'] as List).first['blocks'] as List).add({
      'id': 'psalter',
      'title': 'Псалтирь',
      'kind': 'psalter',
      'key': 'psaltir',
      'part': 'morning',
      'weekdays': [1, 2, 3, 4, 5, 6, 7],
      'mode': 'continuous',
      'unit': 'statia',
    });
    var s = initialCircleState(c);
    final first = op(0, 'mark', {'blockId': 'psalter', 'done': true});
    s = applyCircleOperation(s, first, now: now);
    expect(circleMap(s['cursors'])['psalter'], 1);
    expect(applyCircleOperation(s, first, now: now), s);
    s = applyCircleOperation(
      s,
      op(1, 'mark', {'blockId': 'psalter', 'done': false}),
      now: now,
    );
    s = applyCircleOperation(
      s,
      op(2, 'mark', {'blockId': 'psalter', 'done': true}),
      now: now,
    );
    expect(circleMap(s['cursors'])['psalter'], 1);
    expect(
      circleMap(ensureCircleCycle(s, '2026-11-03')['cursors'])['psalter'],
      1,
    );
  });
  test('schedule mode leaves continuous position unchanged', () {
    final c = initialCircleConfig();
    ((c['variants'] as List).first['blocks'] as List).add({
      'id': 'psalter',
      'title': 'Псалтирь',
      'kind': 'psalter',
      'key': 'psaltir',
      'part': 'morning',
      'weekdays': [1, 2, 3, 4, 5, 6, 7],
      'mode': 'scheduled',
      'unit': 'kathisma',
      'schedule': {
        '1': [17],
      },
    });
    var s = initialCircleState(c);
    (s['cursors'] as Map)['psalter'] = 48;
    s = applyCircleOperation(
      s,
      op(0, 'mark', {'blockId': 'psalter', 'done': true}),
      now: now,
    );
    expect(circleMap(s['cursors'])['psalter'], 48);
  });
  test('guest data is retained when private snapshots are removed', () async {
    SharedPreferences.setMockInitialValues({
      'prayer-circle:guest': 'guest',
      'prayer-circle:user:one': 'private',
      'prayer-circle:user:one:preview:2026-11-01': 'names',
      'prayer-circle:catalog': 'public',
    });
    await clearPrivatePrayerCircleCache();
    final p = await SharedPreferences.getInstance();
    expect(p.getString('prayer-circle:guest'), 'guest');
    expect(p.getString('prayer-circle:catalog'), 'public');
    expect(p.getString('prayer-circle:user:one'), 'private');
    expect(p.getString('prayer-circle:user:one:preview:2026-11-01'), isNull);
  });
  test('owner check prevents saving another account data', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = PrayerCircleRepository('one', owner: () => 'two');
    expect(() => repo.save({'state': {}}), throwsStateError);
  });
  test('preparation marks survive the next daily cycle', () {
    final c = initialCircleConfig();
    c['communion'] = {'date': '2026-11-05', 'days': 3};
    var state = initialCircleState(c);
    state = applyCircleOperation(
      state,
      op(0, 'communion-mark', {'blockId': 'canon:0', 'done': true}),
      now: now,
    );
    expect(
      circleMap(
        ensureCircleCycle(state, '2026-11-02')['marks'],
      )['communion:2026-11-05:canon:0'],
      true,
    );
  });
  test('invalid Scripture ranges are rejected before saving offline', () {
    final c = initialCircleConfig();
    ((c['variants'] as List).first['blocks'] as List).add({
      'id': 'invalid',
      'kind': 'scripture',
      'key': 'ioanna',
      'title': 'Евангелие',
      'part': 'morning',
      'weekdays': [1],
      'chapter': 0,
    });
    expect(() => validateCircleConfig(c), throwsFormatException);
  });
  test(
    'legacy rule and preparation migrate without clearing the verse bookmark',
    () async {
      SharedPreferences.setMockInitialValues({
        'rule_gender': 'f',
        'rule_morning_horologion': true,
        'rule_remind_morning': true,
        'communion_plan_start': '2026-11-01',
        'communion_plan_date': '2026-11-05',
        'communion_done:2026-11-05:service': true,
        'psalter:serial': '{"chapter":118,"verse":80}',
      });
      final repo = PrayerCircleRepository(null, owner: () => null);
      final state = await repo.migrateLegacy();
      final config = circleMap(state['config']);
      expect(config['gender'], 'f');
      expect(
        circleList(
          circleList(config['variants']).first['blocks'],
        ).any((b) => b['id'] == 'morning_horologion'),
        true,
      );
      expect(circleMap(config['communion'])['days'], 3);
      expect(state['legacyPsalterCursor'], 49);
      expect(
        circleMap(state['communionMarks'])['communion:2026-11-05:service'],
        true,
      );
      final p = await SharedPreferences.getInstance();
      expect(p.getString('psalter:serial'), contains('80'));
    },
  );
  test(
    'future Psalter previews rebase and unit changes keep the next boundary',
    () {
      final config = initialCircleConfig();
      (config['variants'] as List).first['blocks'] = [
        {
          'id': 'ps',
          'title': 'Псалтирь',
          'kind': 'psalter',
          'key': 'psaltir',
          'part': 'evening',
          'weekdays': [1, 2, 3, 4, 5, 6, 7],
          'mode': 'continuous',
          'unit': 'kathisma',
        },
      ];
      var state = initialCircleState(config);
      ensureCircleCycle(state, '2026-11-01');
      ensureCircleCycle(state, '2026-11-02');
      state = applyCircleOperation(
        state,
        op(0, 'mark', {'blockId': 'ps', 'done': true}),
        now: now,
      );
      expect(
        circleMap(ensureCircleCycle(state, '2026-11-02')['cursors'])['ps'],
        3,
      );
      state = applyCircleOperation(state, {
        ...op(1, 'mark', {'blockId': 'ps', 'done': true}),
        'cycle': '2026-11-02',
      }, now: now);
      expect(circleMap(state['cursors'])['ps'], 6);
      var switched = initialCircleState(config);
      switched['cursors'] = {'ps': 49};
      switched = applyCircleOperation(
        switched,
        op(0, 'mark', {'blockId': 'ps', 'done': true}),
        now: now,
      );
      expect(circleMap(switched['cursors'])['ps'], 51);
    },
  );

  test(
    'logout clears private legacy preparation without losing the guest circle',
    () async {
      final guest = initialCircleState(initialCircleConfig());
      SharedPreferences.setMockInitialValues({
        'prayer-circle:guest': jsonEncode({
          'state': guest,
          'queue': [],
          'hasRemote': false,
        }),
        'prayer-circle:legacy-owner': 'user:A',
        'communion_plan_start': '2026-11-01',
        'communion_plan_date': '2026-11-04',
        'communion_done:2026-11-04:service': true,
        'communion_active_item_ids:2026-11-04': <String>['service'],
        'rule_done:2026-11-01:morning': true,
        'prayer-circle:user:A:preview:rule:2026-11-01': 'private texts',
      });
      await clearPrivatePrayerCircleCache();
      final p = await SharedPreferences.getInstance();
      expect(p.getString('communion_plan_date'), isNull);
      expect(p.getBool('communion_done:2026-11-04:service'), isNull);
      expect(
        p.getString('prayer-circle:user:A:preview:rule:2026-11-01'),
        isNull,
      );
      expect(p.getString('prayer-circle:guest'), isNotNull);
      final restored = await PrayerCircleRepository(
        null,
        owner: () => null,
      ).load();
      expect(
        circleMap(circleMap(restored['state'])['config'])['communion'],
        isNull,
      );
    },
  );
  test('pruned cycle retains completion in history', () {
    var state = initialCircleState(initialCircleConfig());
    state = applyCircleOperation(
      state,
      op(0, 'mark', {'blockId': 'evening_prayerbook', 'done': true}),
      now: now,
    );
    for (var n = 0; n < 55; n++) {
      ensureCircleCycle(state, dayKey(DateTime(2026, 11, 2 + n)));
    }
    final history = circleMap(state['history']);
    expect(
      circleList(circleMap(history['2026-11-01'])['blocks']).first['done'],
      true,
    );
  });
}
