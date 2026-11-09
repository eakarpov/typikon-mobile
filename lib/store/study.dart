import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../domain/study.dart';
import '../api/v2/request.dart';
import '../apiMapper/session.dart';
import '../apiMapper/v2/errors.dart';
import 'store.dart';

typedef StudyTransport =
    Future<dynamic> Function(String method, String path, StudyJson? body);
Future<void> clearPrivateStudyCache({Directory? root}) async {
  await Future.wait([...StudyRepository._tails.values]);
  final cacheRoot = Directory(
    '${root?.path ?? (await getApplicationSupportDirectory()).path}/study',
  );
  if (!await cacheRoot.exists()) return;
  await for (final e in cacheRoot.list()) {
    if (e is Directory && e.path.split('/').last.startsWith('user-')) {
      final key = 'personal-${sha256.convert(utf8.encode('personal'))}.json';
      final file = File('${e.path}/$key');
      String? pending;
      if (await file.exists())
        try {
          final raw = await file.readAsString(),
              doc = studyMap(jsonDecode(raw));
          if (studyList(doc['queue']).isNotEmpty ||
              studyList(doc['conflicts']).isNotEmpty)
            pending = raw;
        } catch (_) {}
      await e.delete(recursive: true);
      if (pending != null) {
        await e.create(recursive: true);
        await File('${e.path}/$key').writeAsString(pending, flush: true);
      }
    }
  }
}

class StudyConflict implements Exception {
  final dynamic remote;
  StudyConflict(this.remote);
}

class StudyRepository {
  final String? userId;
  final String? Function() owner;
  final StudyTransport? transport;
  final Directory? root;
  StudyRepository(
    this.userId, {
    String? Function()? owner,
    this.transport,
    this.root,
  }) : owner = owner ?? (() => appStore?.state.auth.userId);
  String get scope => userId == null ? 'guest' : 'user-$userId';
  void check() {
    if (owner() != userId)
      throw StateError('Вход изменился. Откройте библиотеку заново.');
  }

  String fileKey(String key) =>
      '${key.split(':').first.split('?').first}-${sha256.convert(utf8.encode(key))}';
  static final Map<String, Future<void>> _tails = {};
  String get lockKey => '${root?.path ?? 'app'}:$scope';
  Future<T> locked<T>(Future<T> Function() action) async {
    final previous = _tails[lockKey] ?? Future.value(),
        done = Completer<void>();
    _tails[lockKey] = done.future;
    await previous;
    try {
      return await action();
    } finally {
      done.complete();
      if (identical(_tails[lockKey], done.future)) _tails.remove(lockKey);
    }
  }

  Future<Directory> directory() async {
    check();
    final d = Directory(
      '${root?.path ?? (await getApplicationSupportDirectory()).path}/study/$scope',
    );
    await d.create(recursive: true);
    check();
    return d;
  }

  Future<dynamic> cached(String key) async {
    check();
    try {
      final d = await directory(), f = File('${d.path}/${fileKey(key)}.json');
      if (!await f.exists()) return null;
      final data = jsonDecode(await f.readAsString());
      check();
      return data;
    } on StateError {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<void> cache(String key, dynamic value) async {
    check();
    final d = await directory(),
        f = File('${d.path}/${fileKey(key)}.json'),
        temp = File('${d.path}/${fileKey(key)}.${studyId()}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    if (owner() != userId) {
      await temp.delete();
      check();
    }
    await temp.rename(f.path);
    if (owner() != userId) {
      if (await f.exists()) await f.delete();
      check();
    }
  }

  Future<dynamic> request(String method, String path, [StudyJson? body]) async {
    check();
    if (transport != null) {
      final d = await transport!(method, path, body);
      check();
      return d;
    }
    final response =
        userId != null &&
            ['personal', 'change', 'publish', 'plan'].contains(path)
        ? await withSession(
            () => v2Send(method, v2Uri('/study/$path'), body: body),
          )
        : await v2Send(method, v2Uri('/study/$path'), body: body);
    check();
    if (response.statusCode == 409)
      throw StudyConflict(
        studyMap(jsonDecode(response.body))['error']?['remote'],
      );
    if (response.statusCode >= 400 &&
        response.statusCode < 500 &&
        response.statusCode != 401 &&
        response.statusCode != 403 &&
        response.statusCode != 404 &&
        response.statusCode != 429)
      throw ApiNotFoundException(
        v2ErrorMessage(response, "Материал недоступен"),
      );
    if (response.statusCode != 200)
      throwV2Error(response, 'Библиотека временно недоступна');
    return jsonDecode(response.body);
  }

  Future<StudyJson> public(String path, {StudyJson? body, String? key}) async {
    key ??= path;
    try {
      final d = studyMap(
        await request(body == null ? 'GET' : 'POST', path, body),
      );
      await cache(key, d);
      return d;
    } catch (e) {
      if (e is ApiUnauthorizedException ||
          e is ApiNotFoundException ||
          e is ApiRateLimitedException)
        rethrow;
      check();
      final old = await cached(key);
      if (old == null) rethrow;
      return studyMap(old);
    }
  }

  Future<StudyJson> load() async {
    check();
    final local = studyMap(await cached('personal'));
    if (userId != null) {
      try {
        final remote = studyMap(await request('GET', 'personal'));
        if (remote['userId'] != userId) throw StateError('Вход изменился.');
        if (studyList(local['queue']).isEmpty) {
          final d = {
            'state': remote['state'],
            'queue': <dynamic>[],
            'conflicts': local['conflicts'] ?? [],
          };
          await cache('personal', d);
          return d;
        }
      } catch (_) {
        check();
      }
    }
    return local.isEmpty
        ? {
            'state': emptyStudy(),
            'queue': <dynamic>[],
            'conflicts': <dynamic>[],
          }
        : local;
  }

  Future<StudyJson> operate(
    StudyJson doc,
    String entity,
    StudyJson value, {
    bool deleted = false,
  }) => locked(() async {
    check();
    final latest = studyMap(await cached('personal'));
    if (latest.isNotEmpty) doc = latest;
    final state = studyMap(doc['state']),
        old = studyList(
          state[entity],
        ).where((v) => v['id'] == value['id']).firstOrNull;
    final op = {
      'entity': entity,
      'value': value,
      'revision': old?['revision'] ?? value['revision'] ?? 0,
      'opId': studyId(),
      'deleted': deleted,
    };
    final next = {
      ...doc,
      'state': studyUpsert(state, entity, value, deleted: deleted),
      'queue': userId == null
          ? <dynamic>[]
          : [
              ...studyList(doc['queue']).where(
                (p) =>
                    !(p['refused'] == true &&
                        p['entity'] == entity &&
                        p['value']['id'] == value['id']),
              ),
              op,
            ],
    };
    await cache('personal', next);
    return next;
  });

  Future<StudyJson> sync(StudyJson doc) async {
    if (userId == null) return doc;
    check();
    while (true) {
      final latest = studyMap(await cached('personal'));
      if (latest.isNotEmpty) doc = latest;
      final queue = studyList(doc['queue']);
      if (queue.isEmpty) return doc;
      final op = queue.first;
      StudyJson? value;
      dynamic remote;
      bool conflict = false;
      try {
        final response = studyMap(
          await request('POST', 'change', {...op, 'expectedUserId': userId}),
        );
        if (response['userId'] != userId) throw StateError('Вход изменился.');
        value = studyMap(response['value']);
      } on ApiNotFoundException {
        final corrected = await locked(() async {
          final stored = studyMap(await cached('personal'));
          if (stored.isNotEmpty) doc = stored;
          final pending = studyList(doc['queue']),
              newer = pending.any(
                (p) =>
                    p['opId'] != op['opId'] &&
                    p['entity'] == op['entity'] &&
                    p['value']['id'] == op['value']['id'],
              );
          final next = {
            ...doc,
            'queue': newer
                ? pending.where((p) => p['opId'] != op['opId']).toList()
                : pending
                      .map(
                        (p) => p['opId'] == op['opId']
                            ? {...p, 'refused': true}
                            : p,
                      )
                      .toList(),
          };
          await cache('personal', next);
          return newer;
        });
        if (corrected) continue;
        rethrow;
      } on StudyConflict catch (e) {
        conflict = true;
        remote = e.remote;
      }
      doc = await locked(() async {
        final stored = studyMap(await cached('personal'));
        if (stored.isNotEmpty) doc = stored;
        if (!studyList(doc['queue']).any((p) => p['opId'] == op['opId']))
          return doc;
        var state = studyMap(doc['state']);
        final pending = studyList(
              doc['queue'],
            ).where((p) => p['opId'] != op['opId']).toList(),
            conflicts = studyList(doc['conflicts']);
        if (conflict) {
          conflicts.add({...op, 'remote': remote});
        } else {
          state = studyUpsert(
            state,
            op['entity'],
            value!,
            deleted: op['deleted'] == true,
          );
          for (final p in pending.where(
            (p) =>
                p['entity'] == op['entity'] && p['value']['id'] == value!['id'],
          )) {
            p['revision'] = value['revision'];
            state = studyUpsert(
              state,
              p['entity'],
              studyMap(p['value']),
              deleted: p['deleted'] == true,
            );
          }
        }
        final next = {'state': state, 'queue': pending, 'conflicts': conflicts};
        await cache('personal', next);
        return next;
      });
    }
  }

  Future<StudyJson> material(StudyJson target) => public(
    'material',
    body: {'target': target},
    key: 'material:${studyTargetKey(target)}',
  );
  Future<StudyJson> package(List<StudyJson> targets) async {
    final unique = <String, StudyJson>{
      for (final t in targets) studyTargetKey(t): t,
    }.values.toList();
    if (unique.isEmpty)
      throw StateError('В подборке нет материалов для скачивания.');
    final materials = <StudyJson>[], missing = <StudyJson>[];
    int bytes = 0, linksMissing = 0;
    for (var start = 0; start < unique.length; start += 40) {
      final chunk = studyMap(
        await request('POST', 'package', {
          'targets': unique.sublist(
            start,
            (start + 40).clamp(0, unique.length),
          ),
        }),
      );
      materials.addAll(studyList(chunk['materials']));
      missing.addAll(studyList(chunk['missing']));
      bytes += (chunk['bytes'] as num? ?? 0).toInt();
    }
    final pack = <String, dynamic>{
      'materials': materials,
      'missing': missing,
      'complete': missing.isEmpty && materials.length == unique.length,
      'bytes': bytes,
    };
    for (final m in studyList(pack['materials'])) {
      final key = 'material:${studyTargetKey(studyMap(m['target']))}',
          old = studyMap(await cached(key));
      if ((m['missing'] as List? ?? []).isEmpty ||
          old.isEmpty ||
          (old['missing'] as List? ?? []).isNotEmpty)
        await cache(key, m);
      try {
        await public(
          'related',
          body: {'target': m['target']},
          key: 'related:${jsonEncode(m['target'])}',
        );
      } catch (_) {
        check();
        linksMissing++;
      }
    }
    pack['linksMissing'] = linksMissing;
    return pack;
  }

  Future<List<StudyJson>> saved() async {
    final d = await directory(), out = <StudyJson>[];
    await for (final e in d.list()) {
      if (e is File &&
          Uri.decodeComponent(e.path.split('/').last).startsWith('material-')) {
        try {
          final m = studyMap(jsonDecode(await e.readAsString()));
          out.add({
            'title': m['title'],
            'target': m['target'],
            'missing': m['missing'],
            'bytes': utf8.encode(jsonEncode(m)).length,
          });
        } catch (_) {}
      }
    }
    check();
    return out;
  }

  Future<StudyJson> transfer(StudyJson doc) async {
    if (userId == null) return doc;
    final guest = StudyRepository(null, owner: () => null, root: root),
        data = studyMap(await guest.cached('personal'));
    for (final entity in ['records', 'collections', 'positions', 'links']) {
      for (final value in studyList(studyMap(data['state'])[entity])) {
        if (studyList(
          studyMap(doc['state'])[entity],
        ).any((v) => v['id'] == value['id']))
          continue;
        doc = await operate(doc, entity, {...value, 'revision': 0});
      }
    }
    return doc;
  }
}
