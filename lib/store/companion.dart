import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/companion.dart';
import '../api/v2/request.dart';
import '../apiMapper/v2/errors.dart';
import '../apiMapper/session.dart';
import 'store.dart';

Future<void> clearPrivateCompanionCache() async {
  final p = await SharedPreferences.getInstance();
  for (final k
      in p.getKeys().where((k) => k.startsWith('companion:user:')).toList()) {
    await p.remove(k);
  }
}

class CompanionRepository {
  final String? userId;
  final String? Function() owner;
  CompanionRepository(this.userId, {String? Function()? owner})
    : owner = owner ?? (() => appStore?.state.auth.userId);
  String get prefix => 'companion:${userId == null ? 'guest' : 'user:$userId'}';
  void check() {
    if (owner() != userId)
      throw StateError('Вход изменился. Откройте Спутник заново.');
  }

  Future<dynamic> request(
    String method,
    String path, {
    CompanionJson? body,
    bool personal = false,
  }) async {
    check();
    final response = personal && userId != null
        ? await withSession(
            () => v2Send(method, v2Uri('/companion$path'), body: body),
          )
        : await v2Send(method, v2Uri('/companion$path'), body: body);
    check();
    if (response.statusCode != 200)
      throwV2Error(response, 'Спутник временно недоступен');
    return jsonDecode(response.body);
  }

  Future<CompanionJson> catalog() async {
    final p = await SharedPreferences.getInstance();
    try {
      final d = companionMap(await request('GET', '/catalog'));
      await p.setString('companion:catalog', jsonEncode(d));
      return d;
    } catch (_) {
      check();
      final old = p.getString('companion:catalog');
      if (old == null) rethrow;
      return companionMap(jsonDecode(old));
    }
  }

  Future<CompanionJson> day(String date, String? ustav) async {
    check();
    final r = await v2Get(
      v2Uri('/ordo/day', {
        'date': date,
        if (ustav != null && ustav.isNotEmpty) 'ustav': ustav,
      }),
    );
    check();
    if (r.statusCode != 200) throwV2Error(r, 'Не удалось получить службы дня');
    return companionMap(jsonDecode(r.body));
  }

  Future<CompanionJson> load() async {
    check();
    final p = await SharedPreferences.getInstance();
    final old = p.getString('$prefix:progress');
    final local = old == null
        ? {'state': initialCompanionProgress(), 'queue': []}
        : companionMap(jsonDecode(old));
    if (userId == null) return local;
    try {
      final d = companionMap(await request('GET', '/progress', personal: true));
      if (d['userId'] != userId) throw StateError('Вход изменился.');
      if ((local['queue'] as List? ?? []).isEmpty) {
        final result = {'state': d['state'], 'queue': []};
        await save(result);
        return result;
      }
    } catch (_) {
      check();
    }
    return local;
  }

  Future<CompanionJson?> lastViewed() async {
    check();
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('$prefix:last-viewed');
    check();
    return raw == null ? null : companionMap(jsonDecode(raw));
  }

  Future<void> rememberView(CompanionJson entry) async {
    check();
    final p = await SharedPreferences.getInstance();
    await p.setString('$prefix:last-viewed', jsonEncode(entry));
    if (owner() != userId) {
      await p.remove('$prefix:last-viewed');
      check();
    }
  }

  Future<void> save(CompanionJson doc) async {
    check();
    final p = await SharedPreferences.getInstance();
    await p.setString('$prefix:progress', jsonEncode(doc));
    if (owner() != userId) {
      await p.remove('$prefix:progress');
      check();
    }
  }

  Future<CompanionJson> operate(
    CompanionJson doc,
    String action,
    CompanionJson entry, {
    bool? done,
  }) async {
    final state = companionMap(doc['state']);
    final op = {
      'id': companionOperationId(),
      'revision': state['revision'],
      'action': action,
      'entry': entry,
      if (done != null) 'done': done,
    };
    final next = {
      'state': applyCompanionOperation(state, op),
      'queue': userId == null
          ? <dynamic>[]
          : [...(doc['queue'] as List? ?? []), op],
    };
    await save(next);
    return next;
  }

  Future<CompanionJson> sync(CompanionJson doc) async {
    if (userId == null) return doc;
    check();
    final loaded = companionMap(
      await request('GET', '/progress', personal: true),
    );
    if (loaded['userId'] != userId) throw StateError('Вход изменился.');
    var state = companionMap(loaded['state']);
    final queue = companionList(doc['queue']);
    while (queue.isNotEmpty) {
      final op = {
        ...queue.first,
        'revision': state['revision'],
        'expectedUserId': userId,
      };
      final d = companionMap(
        await request('POST', '/progress', personal: true, body: op),
      );
      if (d['userId'] != userId) throw StateError('Вход изменился.');
      state = companionMap(d['state']);
      queue.removeAt(0);
      await save({'state': state, 'queue': queue});
    }
    final next = {'state': state, 'queue': <dynamic>[]};
    await save(next);
    return next;
  }

  Future<CompanionBundle> assemble(CompanionJson selection) async {
    check();
    final p = await SharedPreferences.getInstance();
    selection = {
      for (final e in selection.entries)
        if (e.value != null && e.value != '') e.key: e.value,
    };
    final sig = companionSignature(selection);
    try {
      final b = CompanionBundle.fromJson(
        await request('POST', '/assemble', body: selection),
      );
      final data = {...b.data, 'trusted': true};
      check();
      for (final service in companionList(data['services'])) {
        final key = '$prefix:snapshot:${service['sessionKey']}';
        final previous = p.getString(key);
        final old = previous == null
            ? null
            : companionMap(jsonDecode(previous));
        final complete = companionList(
          data['services'],
        ).every((s) => companionMap(s['coverage'])['texts'] == true);
        final oldComplete =
            old != null &&
            companionList(
              companionMap(old['bundle'])['services'],
            ).every((s) => companionMap(s['coverage'])['texts'] == true);
        if (complete || !oldComplete || old['signature'] != sig)
          await p.setString(
            key,
            jsonEncode({
              'selection': selection,
              'signature': sig,
              'bundle': data,
            }),
          );
        if (owner() != userId) {
          await p.remove(key);
          check();
        }
      }
      return CompanionBundle(data);
    } catch (_) {
      check();
      for (final key in p.getKeys().where(
        (k) => k.startsWith('$prefix:snapshot:'),
      )) {
        final d = companionMap(jsonDecode(p.getString(key)!));
        if (d['signature'] == sig)
          return CompanionBundle({
            ...companionMap(d['bundle']),
            'offline': true,
          });
      }
      rethrow;
    }
  }

  Future<void> cacheBundle(CompanionJson selection, CompanionJson data) async {
    check();
    final p = await SharedPreferences.getInstance();
    for (final s in companionList(data['services'])) {
      final key = '$prefix:snapshot:${s['sessionKey']}';
      final raw = p.getString(key);
      if (raw != null) {
        final previous = companionMap(jsonDecode(raw));
        final oldComplete = companionList(
          companionMap(previous['bundle'])['services'],
        ).every((s) => companionMap(s['coverage'])['texts'] == true);
        final complete = companionList(
          data['services'],
        ).every((s) => companionMap(s['coverage'])['texts'] == true);
        if (oldComplete &&
            !complete &&
            previous['signature'] == companionSignature(selection))
          continue;
      }
      await p.setString(
        key,
        jsonEncode({
          'selection': selection,
          'signature': companionSignature(selection),
          'bundle': data,
        }),
      );
      if (owner() != userId) {
        await p.remove(key);
        check();
      }
    }
  }

  Future<CompanionBundle?> cached(String key) async {
    check();
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('$prefix:snapshot:$key');
    if (raw == null) return null;
    return CompanionBundle({
      ...companionMap(companionMap(jsonDecode(raw))['bundle']),
      'offline': true,
    });
  }

  Future<CompanionJson> transferGuest(CompanionJson doc) async {
    check();
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('companion:guest:progress');
    if (raw == null) return doc;
    var next = doc;
    final guest = companionMap(jsonDecode(raw));
    for (final key
        in p
            .getKeys()
            .where((k) => k.startsWith('companion:guest:snapshot:'))
            .toList()) {
      final target = key.replaceFirst('companion:guest', prefix);
      if (!p.containsKey(target)) {
        await p.setString(target, p.getString(key)!);
        if (owner() != userId) {
          await p.remove(target);
          check();
        }
      }
    }
    final guestView = p.getString('companion:guest:last-viewed');
    if (guestView != null && !p.containsKey('$prefix:last-viewed')) {
      await p.setString('$prefix:last-viewed', guestView);
      if (owner() != userId) {
        await p.remove('$prefix:last-viewed');
        check();
      }
    }
    for (final e in companionMap(
      companionMap(guest['state'])['entries'],
    ).values) {
      final entry = companionMap(e);
      for (final mark in companionMap(entry['saved']).entries) {
        next = await operate(next, 'save', {
          ...entry,
          'nodeId': mark.key,
          'lineId': null,
          'lineHash': null,
          'contentHash':
              companionMap(
                companionMap(entry['savedDetails'])[mark.key],
              )['contentHash'] ??
              'unknown',
          'nodeTitle':
              companionMap(
                companionMap(entry['savedDetails'])[mark.key],
              )['title'] ??
              'Сохранённая часть',
        }, done: mark.value == true);
      }
      next = await operate(next, 'position', entry);
    }
    return sync(next);
  }
}
