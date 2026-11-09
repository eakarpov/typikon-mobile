import '../components/note_sharing.dart';
import '../components/study_source_text.dart';
import '../components/script_toggle.dart';
import '../components/pinch_zoom.dart';
import '../utils/script_convert.dart';
import '../components/word_sheet.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/study.dart';
import '../store/study.dart';
import '../store/reading_progress.dart';
import '../store/store.dart';
import '../components/reading_markdown.dart';
import '../components/service_reading_scope.dart';
import '../utils/service_mode.dart';
import '../utils/reading_style.dart';

class StudyPage extends StatefulWidget {
  final StudyJson? initialTarget;
  final StudyRepository? repository;
  const StudyPage({super.key, this.initialTarget, this.repository});
  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> with WidgetsBindingObserver {
  late StudyRepository repo;
  StudyJson? catalog, book, material, selected, related, notebook, linkStart;
  StudyJson doc = {
    'state': emptyStudy(),
    'queue': <dynamic>[],
    'conflicts': <dynamic>[],
  };
  StudyJson? readingNotebook, rangeStart, rebind;
  String readingItemId = '';
  List<SavedReading> legacyPositions = [];
  List<StudyJson> routes = [], saved = [], stack = [];
  String workFilter = '',
      tab = 'catalog',
      panel = 'related',
      search = '',
      language = '',
      category = '',
      tag = '',
      bookFilter = '',
      collectionFilter = '',
      message = '',
      error = '';
  bool busy = false, ready = false, questionsOnly = false, syncing = false;
  int generation = 0;
  final scroll = ScrollController();
  Timer? positionTimer, restoreTimer;
  StreamSubscription? accountSubscription;
  int opening = 0;
  bool restoringScroll = false;
  int bookLimit = 100;
  final keys = <String, GlobalKey>{};
  StudyJson get state => studyMap(doc['state']);
  List<StudyJson> list(String kind) => studyList(state[kind]);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scroll.addListener(() {
      if (material == null || restoringScroll || busy) return;
      positionTimer?.cancel();
      positionTimer = Timer(
        const Duration(seconds: 2),
        () => unawaited(rememberVisible()),
      );
    });
    repo = widget.repository ?? StudyRepository(appStore?.state.auth.userId);
    accountSubscription = appStore?.onChange.listen((s) {
      if (widget.repository == null && repo.userId != s.auth.userId) {
        generation++;
        opening++;
        positionTimer?.cancel();
        setState(() {
          material = null;
          selected = null;
          notebook = null;
          readingNotebook = null;
          related = null;
          linkStart = null;
          rebind = null;
          rangeStart = null;
          stack = [];
          doc = {
            'state': emptyStudy(),
            'queue': <dynamic>[],
            'conflicts': <dynamic>[],
          };
        });
        unawaited(boot());
      }
    });
    unawaited(boot());
  }

  @override
  void dispose() {
    generation++;
    positionTimer?.cancel();
    restoreTimer?.cancel();
    accountSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    super.dispose();
  }

  void report(Object e) {
    if (mounted)
      setState(
        () => error = e is StateError
            ? 'Вход изменился. Обновите данные входа.'
            : e.toString().replaceFirst('Exception: ', ''),
      );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused) unawaited(rememberVisible());
  }

  Future<void> rememberVisible() async {
    if (!mounted || material == null || restoringScroll || busy) return;
    final blocks = studyList(material!['blocks']);
    StudyJson? best;
    double distance = double.infinity;
    for (final b in blocks) {
      final render = keys['${b['id']}']?.currentContext?.findRenderObject();
      if (render is! RenderBox || !render.attached) continue;
      final y = render.localToGlobal(Offset.zero).dy;
      if (y + render.size.height < 100 || y > MediaQuery.sizeOf(context).height)
        continue;
      final d = (y - 160).abs();
      if (d < distance) {
        distance = d;
        best = b;
      }
    }
    if (best == null) return;
    final old = list('positions')
        .where(
          (p) =>
              p['collectionId'] == null &&
              studyTargetKey(studyMap(p['target'])) ==
                  studyTargetKey(studyMap(material!['target'])),
        )
        .firstOrNull;
    if (studyMap(old?['target'])['blockId'] == best['id']) return;
    await save('positions', {
      'id': old?['id'] ?? studyId(),
      'revision': old?['revision'] ?? 0,
      'target': studyTargetAt(material!, best),
      'title': material!['title'],
      'status': old?['status'] ?? 'reading',
    }, silent: true);
  }

  Future<void> boot() async {
    final gen = ++generation;
    setState(() => busy = true);
    try {
      repo = widget.repository ?? StudyRepository(appStore?.state.auth.userId);
      final oldPositions = await getAllReadingProgress();
      final d = await repo.load(),
          c = await repo.public('catalog'),
          r = await repo.public('routes'),
          s = await repo.saved();
      if (!mounted || gen != generation) return;
      setState(() {
        doc = d;
        legacyPositions = oldPositions
            .where((p) => RegExp(r'^[a-f0-9]{24}(?:#.*)?$').hasMatch(p.id))
            .toList();
        catalog = c;
        routes = studyList(r['routes']);
        saved = s;
        ready = true;
        busy = false;
      });
      if (widget.initialTarget != null && material == null)
        await open(widget.initialTarget!, remember: false);
    } catch (e) {
      report(e);
      if (mounted)
        setState(() {
          busy = false;
          ready = true;
        });
    }
  }

  Future<bool> save(
    String entity,
    StudyJson value, {
    bool deleted = false,
    bool silent = false,
  }) async {
    try {
      final latest = list(
        entity,
      ).where((v) => v['id'] == value['id']).firstOrNull;
      final next = await repo.operate(doc, entity, {
        ...value,
        'revision': latest?['revision'] ?? value['revision'] ?? 0,
      }, deleted: deleted);
      if (!mounted) return false;
      setState(() {
        doc = next;
        if (notebook?['id'] == value['id'] && entity == 'collections')
          notebook = deleted ? null : value;
        if (!silent) message = 'Сохранено на устройстве.';
      });
      if (entity == 'positions' &&
          value['collectionId'] == null &&
          readingNotebook != null &&
          studyList(readingNotebook!['items']).any(
            (i) =>
                i['id'] == readingItemId &&
                i['target'] != null &&
                studyTargetKey(studyMap(i['target'])) ==
                    studyTargetKey(studyMap(value['target'])),
          )) {
        await save('positions', {
          'id': 'notebook-${readingNotebook!['id']}',
          'target': value['target'],
          'title': readingNotebook!['title'],
          'collectionId': readingNotebook!['id'],
          'itemId': readingItemId,
          'status':
              list('positions')
                  .where((p) => p['collectionId'] == readingNotebook!['id'])
                  .firstOrNull?['status'] ??
              'reading',
        }, silent: true);
      }
      if (repo.userId != null) unawaited(sync());
      return true;
    } catch (e) {
      report(e);
      return false;
    }
  }

  Future<void> sync() async {
    if (syncing) return;
    syncing = true;
    try {
      final next = await repo.sync(doc);
      if (!mounted) return;
      setState(() {
        doc = next;
        message = studyList(doc['conflicts']).isEmpty
            ? 'Записи синхронизированы.'
            : 'Есть конфликт правок: выберите версию в «Моём чтении».';
      });
    } catch (e) {
      report(e);
    } finally {
      syncing = false;
    }
  }

  Future<void> open(StudyJson target, {bool remember = true}) async {
    final gen = generation, requestId = ++opening;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (remember && material != null)
        stack.add({
          'title': material!['title'],
          'target': selected ?? material!['target'],
          'context': readingNotebook,
          'itemId': readingItemId,
        });
      final m = await repo.material(target);
      if (!mounted || gen != generation || requestId != opening) return;
      final exact = studyLocate(m, target),
          old = list('positions')
              .where(
                (p) =>
                    p['collectionId'] == null &&
                    studyTargetKey(studyMap(p['target'])) ==
                        studyTargetKey(studyMap(m['target'])),
              )
              .firstOrNull;
      final restored =
              exact ??
              (old == null ? null : studyLocate(m, studyMap(old['target']))),
          blocks = studyList(m['blocks']),
          focus = restored ?? blocks.firstOrNull;
      keys.clear();
      setState(() {
        material = m;
        selected = focus == null
            ? studyMap(m['target'])
            : target['kind'] == 'bible' &&
                  target['verseFrom'] != null &&
                  target['verseTo'] != null &&
                  target['verseTo'] > target['verseFrom'] &&
                  blocks.any((b) => b['verse'] == target['verseTo'])
            ? studyRangeTarget(
                m,
                focus['id'],
                blocks.firstWhere((b) => b['verse'] == target['verseTo'])['id'],
              )
            : restored != null && target['quote'] != null
            ? {
                ...target,
                ...studyMap(m['target']),
                'blockId': focus['id'],
                'sourceHash': m['sourceHash'],
              }
            : studyTargetAt(m, focus);
        related = null;
        book = null;
        busy = false;
        if ((target['blockId'] != null ||
                target['quote'] != null ||
                old != null) &&
            restored == null)
          message =
              'Точное место не восстановлено. Выписка сохранена; уточните место.';
      });
      if (focus != null) scrollTo(focus['id']);
      try {
        final links = await repo.public(
          'related',
          body: {'target': target},
          key: 'related:${jsonEncode(target)}',
        );
        if (mounted && gen == generation && requestId == opening)
          setState(() => related = links);
      } catch (_) {
        if (mounted && gen == generation && requestId == opening)
          setState(
            () => related = {
              'notice':
                  'Связи не загружены. Сохраните связанные материалы заранее.',
            },
          );
      }
    } catch (e) {
      report(e);
      if (mounted) setState(() => busy = false);
    }
  }

  void scrollTo(String id) {
    restoringScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = keys[id]?.currentContext;
      if (context != null)
        Scrollable.ensureVisible(
          context,
          alignment: .2,
          duration: const Duration(milliseconds: 200),
        );
      restoreTimer?.cancel();
      restoreTimer = Timer(const Duration(milliseconds: 300), () {
        restoringScroll = false;
      });
    });
  }

  Future<void> loadBook(String id) async {
    setState(() => busy = true);
    try {
      if (material != null)
        stack.add({
          'title': material!['title'],
          'target': selected ?? material!['target'],
          'context': readingNotebook,
          'itemId': readingItemId,
        });
      final b = await repo.public('catalog?book=${Uri.encodeComponent(id)}');
      if (mounted)
        setState(() {
          book = b;
          tab = 'catalog';
          material = null;
          notebook = null;
          bookLimit = 100;
          search = '';
        });
    } catch (e) {
      report(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openItem(
    StudyJson c,
    StudyJson item, {
    StudyJson? resume,
  }) async {
    final target =
        resume ??
        (item['target'] != null
            ? studyMap(item['target'])
            : list('records')
                  .where((r) => r['id'] == item['recordId'])
                  .firstOrNull?['target']);
    if (target == null) {
      notice('Запись удалена или недоступна.');
      return;
    }
    if (material != null)
      stack.add({
        'title': material!['title'],
        'target': selected ?? material!['target'],
        'context': readingNotebook,
        'itemId': readingItemId,
      });
    setState(() {
      readingNotebook = c;
      readingItemId = item['id'];
    });
    await open(studyMap(target), remember: false);
    if (material != null && selected != null)
      await save('positions', {
        'id': 'notebook-${c['id']}',
        'target': selected,
        'title': c['title'],
        'collectionId': c['id'],
        'itemId': item['id'],
        'status':
            list('positions')
                .where((p) => p['collectionId'] == c['id'])
                .firstOrNull?['status'] ??
            'reading',
      }, silent: true);
  }

  StudyJson routeNotebook(StudyJson r) => {
    'id': 'route-${r['id']}',
    'title': r['title'],
    'items': studyList(r['items'])
        .asMap()
        .entries
        .map(
          (e) => {
            ...e.value,
            'id': e.value['id'] ?? 'step-${e.key}',
            'kind': 'source',
          },
        )
        .toList(),
  };
  StudyJson bookNotebook(StudyJson b) => {
    'id': 'book-${b['book']['id']}',
    'title': b['book']['title'],
    'items': studyList(b['texts'])
        .map(
          (t) => {
            'id': t['id'],
            'kind': 'source',
            'title': t['title'],
            'target': {...studyMap(t['target']), 'edition': b['book']['id']},
          },
        )
        .toList(),
  };
  Future<void> resumePosition(StudyJson p) async {
    if ('${p['collectionId'] ?? ''}'.startsWith('book-'))
      try {
        final b = await repo.public(
              'catalog?book=${Uri.encodeComponent('${p['collectionId']}'.substring(5))}',
            ),
            c = bookNotebook(b),
            item = studyList(
              c['items'],
            ).where((i) => i['id'] == p['itemId']).firstOrNull;
        if (item != null) {
          await openItem(c, item, resume: studyMap(p['target']));
          return;
        }
      } catch (_) {
        notice('Оглавление книги пока недоступно. Открыто сохранённое место.');
      }

    if (p['collectionId'] != null) {
      final c = [
        ...list('collections'),
        ...routes.map(routeNotebook),
      ].where((c) => c['id'] == p['collectionId']).firstOrNull;
      final item = studyList(
        c?['items'],
      ).where((i) => i['id'] == p['itemId']).firstOrNull;
      if (c != null && item != null) {
        await openItem(c, item, resume: studyMap(p['target']));
        return;
      }
    }
    readingNotebook = null;
    await open(studyMap(p['target']));
  }

  Future<void> position([String? status]) async {
    if (material == null || selected == null) return;
    final old = list('positions')
        .where(
          (p) =>
              p['collectionId'] == null &&
              studyTargetKey(studyMap(p['target'])) ==
                  studyTargetKey(studyMap(material!['target'])),
        )
        .firstOrNull;
    await save('positions', {
      'id': old?['id'] ?? studyId(),
      'revision': old?['revision'] ?? 0,
      'target': selected,
      'title': material!['title'],
      'status': status ?? old?['status'] ?? 'reading',
    });
    if (status != null && '${readingNotebook?['id'] ?? ''}'.startsWith('book-'))
      await save('positions', {
        'id': 'notebook-${readingNotebook!['id']}',
        'target': selected,
        'title': readingNotebook!['title'],
        'collectionId': readingNotebook!['id'],
        'itemId': readingItemId,
        'status': status,
      });
  }

  Future<void> download(List<StudyJson> targets) async {
    if (targets.isEmpty) {
      setState(() => error = 'В подборке нет материалов для скачивания.');
      return;
    }
    setState(() => busy = true);
    try {
      final pack = await repo.package(targets);
      final s = await repo.saved();
      if (mounted)
        setState(() {
          saved = s;
          message = pack['complete'] == true
              ? 'Все выбранные материалы сохранены без сети.'
              : 'Копия неполная: ${studyList(pack['missing']).map((m) => m['reason']).join('; ')}';
          message +=
              ' ${((pack['bytes'] as num? ?? 0) / 1048576).toStringAsFixed(2)} МБ. ';
          message += pack['linksMissing'] == 0
              ? 'Справки связей сохранены; тексты по ссылкам скачиваются отдельно.'
              : 'Не загружены справки связей: ${pack['linksMissing']}.';
        });
    } catch (e) {
      report(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget action(String title, VoidCallback onPressed, {bool enabled = true}) =>
      OutlinedButton(onPressed: enabled ? onPressed : null, child: Text(title));
  Widget heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
  Widget textField(
    String label,
    String value,
    ValueChanged<String> changed, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      maxLines: lines,
      onChanged: changed,
    ),
  );
  Widget choices(
    String label,
    String value,
    List<(String, String)> options,
    ValueChanged<String> changed,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: DropdownButtonFormField<String>(
      initialValue: options.any((o) => o.$1 == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (o) => DropdownMenuItem(
              value: o.$1,
              child: Text(o.$2, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) changed(v);
      },
    ),
  );
  void notice(String value) {
    if (mounted) setState(() => message = value);
  }

  Future<void> editRecord([StudyJson? original, String kind = 'note']) async {
    if (original == null && selected == null) return;
    final value = studyMap(
      jsonDecode(
        jsonEncode(
          original ??
              {
                'id': studyId(),
                'revision': 0,
                'kind': kind,
                'target': selected,
                'originalQuote': selected?['quote'],
                'originalTarget': selected,
                'sourceTitle': material?['title'],
                'sourceBookId': studyMap(material?['metadata'])['bookId'],
                'sourceBookTitle': material?['edition'],
                'note': '',
                'tags': <dynamic>[],
                'questionStatus': 'open',
              },
        ),
      ),
    );
    var body = '${value['note'] ?? ''}',
        tags = (value['tags'] as List? ?? []).join(', ');
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Моя запись'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                snapshotText(
                  '${studyMap(value['target'])['quote'] ?? ''}',
                  maxLines: 5,
                ),
                choices('Вид записи', value['kind'], [
                  ('highlight', 'Выделение'),
                  ('note', 'Заметка'),
                  ('question', 'Вопрос'),
                ], (v) => set(() => value['kind'] = v)),
                textField(
                  'Комментарий / вопрос',
                  body,
                  (v) => body = v,
                  lines: 5,
                ),
                textField('Метки через запятую', tags, (v) => tags = v),
                if (value['kind'] == 'question')
                  choices(
                    'Состояние',
                    value['questionStatus'],
                    [('open', 'Открыт'), ('resolved', 'Разобран')],
                    (v) => set(() => value['questionStatus'] = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                value['note'] = body;
                value['tags'] = tags
                    .split(',')
                    .map((v) => v.trim())
                    .where((v) => v.isNotEmpty)
                    .toList();
                if (await save('records', value) && context.mounted)
                  Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> editCollection([
    StudyJson? original,
    StudyJson? initialTarget,
  ]) async {
    final c = studyMap(
      jsonDecode(
        jsonEncode(
          original ??
              {
                'id': studyId(),
                'revision': 0,
                'title': '',
                'description': '',
                'items': initialTarget == null
                    ? <dynamic>[]
                    : [
                        {
                          'id': studyId(),
                          'kind': 'source',
                          'title': material?['title'] ?? initialTarget['id'],
                          'target': initialTarget,
                        },
                      ],
              },
        ),
      ),
    );
    var title = '${c['title']}', description = '${c['description'] ?? ''}';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подборка'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              textField('Название', title, (v) => title = v),
              textField(
                'Описание',
                description,
                (v) => description = v,
                lines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              if (title.trim().isEmpty) return;
              if (await save('collections', {
                    ...c,
                    'title': title.trim(),
                    'description': description,
                  }) &&
                  context.mounted)
                Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> pickCollection({StudyJson? record}) async {
    if (selected == null && record == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              heading('Добавить в подборку'),
              ...list('collections').map(
                (c) => ListTile(
                  title: Text(c['title']),
                  onTap: () async {
                    final item = record == null
                        ? {
                            'id': studyId(),
                            'kind': 'source',
                            'title': material?['title'] ?? selected!['id'],
                            'target': selected,
                          }
                        : {
                            'id': studyId(),
                            'kind': 'record',
                            'recordId': record['id'],
                            'title': record['kind'] == 'question'
                                ? 'Вопрос'
                                : 'Запись',
                          };
                    await save('collections', {
                      ...c,
                      'items': [...studyList(c['items']), item],
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: const Text('Новая подборка'),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(editCollection(null, selected));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> editItem(StudyJson? existing) async {
    if (notebook == null) return;
    final item = studyMap(
      jsonDecode(
        jsonEncode(
          existing ??
              {'id': studyId(), 'kind': 'section', 'title': '', 'comment': ''},
        ),
      ),
    );
    var title = '${item['title']}', comment = '${item['comment'] ?? ''}';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Элемент подборки'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              textField('Название', title, (v) => title = v),
              textField('Комментарий', comment, (v) => comment = v, lines: 4),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              item['title'] = title;
              item['comment'] = comment;
              final items = studyList(notebook!['items']);
              if (existing == null)
                items.add(item);
              else
                items[items.indexWhere((i) => i['id'] == item['id'])] = item;
              if (await save('collections', {...notebook!, 'items': items}) &&
                  context.mounted)
                Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> createNotebookPlan(StudyJson c) async {
    try {
      await sync();
      final latest = list('collections').firstWhere((v) => v['id'] == c['id']);
      final preview = studyMap(
        await repo.request('POST', 'plan', {
          'action': 'preview',
          'id': c['id'],
          'revision': latest['revision'],
          'expectedUserId': repo.userId,
        }),
      );
      var date = DateTime.now().toIso8601String().substring(0, 10);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Личный план: ${preview['title']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'В план попадут перечисленные тексты. Личные записи останутся в подборке: ${preview['excludedRecords']}.',
                ),
                ...studyList(
                  preview['items'],
                ).map((i) => Text('${i['title']}')),
                if (preview['existingPlan'] != null)
                  Text(
                    'Уже есть личный план «${preview['existingPlan']['title']}». Он сохранён.',
                  )
                else
                  textField('Дата начала: ГГГГ-ММ-ДД', date, (v) => date = v),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
            if (preview['existingPlan'] == null)
              TextButton(
                onPressed: () async {
                  try {
                    await repo.request('POST', 'plan', {
                      'action': 'create',
                      'id': c['id'],
                      'revision': latest['revision'],
                      'date': date,
                      'expectedUserId': repo.userId,
                    });
                    if (context.mounted) Navigator.pop(context);
                    notice(
                      'Личный план создан. В «Моём круге» добавьте блок «Личный план», чтобы подключить его к правилу.',
                    );
                  } catch (e) {
                    report(e);
                  }
                },
                child: const Text('Создать план из этих текстов'),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(this.context).pushNamed('/rule');
              },
              child: const Text('Открыть «Мой круг»'),
            ),
          ],
        ),
      );
    } catch (e) {
      report(e);
    }
  }

  Future<void> shareCollection(StudyJson c) async {
    final included = <String>{};
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Состав опубликованной копии'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Будут доступны название, описание, источники и комментарии элементов. Отметьте личные записи, которые хотите включить.',
                ),
                ...studyList(
                  c['items'],
                ).where((i) => i['kind'] == 'record').map((i) {
                  final r = list(
                    'records',
                  ).where((r) => r['id'] == i['recordId']).firstOrNull;
                  return CheckboxListTile(
                    value: included.contains(i['recordId']),
                    title: Text(
                      '${r?['note'] ?? studyMap(r?['target'])['quote'] ?? 'Запись'}',
                    ),
                    onChanged: (v) => set(() {
                      if (v == true)
                        included.add(i['recordId']);
                      else
                        included.remove(i['recordId']);
                    }),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await sync();
                  final latest = list(
                    'collections',
                  ).firstWhere((x) => x['id'] == c['id']);
                  final r = studyMap(
                    await repo.request('POST', 'publish', {
                      'id': c['id'],
                      'revision': latest['revision'],
                      'recordIds': included.toList(),
                      'expectedUserId': repo.userId,
                    }),
                  );
                  if (context.mounted) Navigator.pop(context);
                  await SharePlus.instance.share(
                    ShareParams(text: 'https://www.typikon.info${r['href']}'),
                  );
                } catch (e) {
                  report(e);
                }
              },
              child: const Text('Опубликовать выбранное'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> export(bool markdown) async {
    final text = markdown
        ? studyMarkdown(state)
        : const JsonEncoder.withIndent('  ').convert(state);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: markdown ? 'Моё чтение · Markdown' : 'Моё чтение · JSON',
      ),
    );
  }

  Widget card(List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  List<Widget> catalogue() {
    if (book != null) {
      final b = studyMap(book!['book']);
      return [
        action('Назад к каталогу', () => setState(() => book = null)),
        heading('${b['title']}'),
        Text(
          '${b['author'] ?? ''} · ${b['edition'] ?? ''} · ${b['languageLabel'] ?? b['language'] ?? ''}',
        ),
        Text('${b['description'] ?? ''}'),
        action(
          'Скачать книгу',
          () => unawaited(
            download(
              studyList(
                book!['texts'],
              ).map((t) => studyMap(t['target'])).toList(),
            ),
          ),
        ),
        textField(
          'Поиск в оглавлении',
          search,
          (v) => setState(() => search = v),
        ),
        ...studyList(book!['texts'])
            .where(
              (t) =>
                  search.isEmpty ||
                  studyNormalize(
                    '${t['title']}',
                  ).contains(studyNormalize(search)),
            )
            .take(bookLimit)
            .map(
              (t) => ListTile(
                title: Text(t['title']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final c = bookNotebook(book!);
                  unawaited(
                    openItem(
                      c,
                      studyList(
                        c['items'],
                      ).firstWhere((i) => i['id'] == t['id']),
                    ),
                  );
                },
              ),
            ),
        if (studyList(book!['texts']).length > bookLimit)
          action('Показать ещё', () => setState(() => bookLimit += 100)),
      ];
    }
    final books = studyList(catalog?['books']);
    return [
      if (workFilter.isNotEmpty)
        action('Все произведения', () => setState(() => workFilter = '')),
      textField(
        'Найти книгу или автора',
        search,
        (v) => setState(() => search = v),
      ),
      choices('Язык', language, [
        ('', 'Все'),
        ...books
            .map((b) => '${b['language'] ?? ''}')
            .where((v) => v.isNotEmpty)
            .toSet()
            .map(
              (v) => (
                v,
                '${books.where((b) => b['language'] == v).firstOrNull?['languageLabel'] ?? v}',
              ),
            ),
      ], (v) => setState(() => language = v)),
      choices('Тематика', category, [
        ('', 'Все'),
        ...books
            .map((b) => '${b['category'] ?? ''}')
            .where((v) => v.isNotEmpty)
            .toSet()
            .map(
              (v) => (
                v,
                '${books.where((b) => b['category'] == v).firstOrNull?['categoryLabel'] ?? v}',
              ),
            ),
      ], (v) => setState(() => category = v)),
      ...books
          .where(
            (b) =>
                (search.isEmpty ||
                    studyNormalize(
                      '${b['title']} ${b['author']} ${b['edition']}',
                    ).contains(studyNormalize(search))) &&
                (language.isEmpty || b['language'] == language) &&
                (category.isEmpty || b['category'] == category) &&
                (workFilter.isEmpty || b['workKey'] == workFilter),
          )
          .map(
            (b) => card([
              Text(
                '${b['title']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${b['author'] ?? ''} · ${b['edition'] ?? ''} · ${b['languageLabel'] ?? b['language'] ?? ''}',
              ),
              if (b['workKey'] != null)
                action(
                  'Все редакции произведения',
                  () => setState(() {
                    workFilter = b['workKey'];
                    language = '';
                    category = '';
                    search = '';
                  }),
                ),
              Text(
                (b['available'] as num? ?? 0) > 0
                    ? 'Текстов доступно: ${b['available']}'
                    : b['bibleEdition'] != null
                    ? 'Издание Библии'
                    : 'Текст пока не подготовлен',
              ),
              if ((b['available'] as num? ?? 0) > 0)
                action('Оглавление', () => unawaited(loadBook(b['id']))),
              if (b['bibleEdition'] != null)
                action(
                  'Открыть Библию',
                  () => Navigator.pushNamed(context, '/bible'),
                ),
            ]),
          ),
    ];
  }

  List<Widget> topics() => [
    heading('Изучить тему'),
    const Text(
      'Подготовленные маршруты с источниками. Их можно скопировать в личную подборку.',
    ),
    ...routes.map(
      (r) => card([
        Text(r['title'], style: Theme.of(context).textTheme.titleLarge),
        Text(r['summary']),
        Text('${r['author']} · ${r['locator']}'),
        action(
          'Скопировать в мои подборки',
          () => unawaited(
            save('collections', {
              'id': studyId(),
              'revision': 0,
              'title': r['title'],
              'description': r['summary'],
              'routeId': r['id'],
              'items': studyList(
                r['items'],
              ).map((i) => {...i, 'id': studyId(), 'kind': 'source'}).toList(),
            }),
          ),
        ),
        action(
          'Скачать маршрут',
          () => unawaited(
            download(
              studyList(r['items']).map((i) => studyMap(i['target'])).toList(),
            ),
          ),
        ),
        ...studyList(r['items']).map(
          (i) => ListTile(
            title: Text(i['title']),
            subtitle: Text('${i['comment']}\n${i['source']}'),
            onTap: () => unawaited(
              openItem(
                routeNotebook(r),
                routeNotebook(r)['items'][studyList(
                  r['items'],
                ).indexWhere((v) => v['title'] == i['title'])],
              ),
            ),
          ),
        ),
      ]),
    ),
    action('Открыть место Писания', () => unawaited(bibleEntry())),
  ];
  Future<void> bibleEntry() async {
    var edition = 'cs-eliz', bookId = 'matfeya', chapter = 6, from = 1, to = 18;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Место Писания'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              choices(
                'Издание',
                edition,
                studyList(
                  catalog?['editions'],
                ).map((e) => ('${e['code']}', '${e['title']}')).toList(),
                (v) => edition = v,
              ),
              choices(
                'Книга',
                bookId,
                studyList(
                  catalog?['scriptureBooks'],
                ).map((b) => ('${b['id']}', '${b['name']}')).toList(),
                (v) => bookId = v,
              ),
              textField(
                'Глава',
                '$chapter',
                (v) => chapter = int.tryParse(v) ?? 1,
              ),
              textField(
                'Стихи от',
                '$from',
                (v) => from = int.tryParse(v) ?? 1,
              ),
              textField('до', '$to', (v) => to = int.tryParse(v) ?? 1),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              unawaited(
                open({
                  'kind': 'bible',
                  'id': bookId,
                  'edition': edition,
                  'chapter': chapter,
                  'verseFrom': from,
                  'verseTo': to,
                }),
              );
            },
            child: const Text('Читать'),
          ),
        ],
      ),
    );
  }

  List<Widget> mine() {
    final notes = list('records')
        .where(
          (r) =>
              (search.isEmpty ||
                  studyNormalize(
                    '${r['note']} ${r['originalQuote'] ?? ''} ${studyMap(r['target'])['quote']} ${(r['tags'] as List? ?? []).join(' ')}',
                  ).contains(studyNormalize(search))) &&
              (tag.isEmpty || (r['tags'] as List? ?? []).contains(tag)) &&
              (bookFilter.isEmpty ||
                  (r['sourceBookId'] ?? studyMap(r['target'])['id']) ==
                      bookFilter) &&
              (!questionsOnly ||
                  r['kind'] == 'question' && r['questionStatus'] == 'open') &&
              (collectionFilter.isEmpty ||
                  studyList(
                    list('collections')
                        .where((c) => c['id'] == collectionFilter)
                        .firstOrNull?['items'],
                  ).any(
                    (i) =>
                        i['recordId'] == r['id'] ||
                        i['target'] != null &&
                            studyTargetKey(studyMap(i['target'])) ==
                                studyTargetKey(studyMap(r['target'])),
                  )),
        )
        .toList();
    return [
      if (legacyPositions.isNotEmpty) heading('Прежние сохранённые места'),
      ...legacyPositions.map(
        (p) => ListTile(
          title: Text(p.progress.name ?? 'Сохранённый текст'),
          subtitle: const Text(
            'Место из прежнего читателя; можно открыть и уточнить привязку.',
          ),
          onTap: () =>
              Navigator.pushNamed(context, '/reading', arguments: p.id),
        ),
      ),

      heading('Моё чтение'),
      Wrap(
        spacing: 8,
        children: [
          action('Выгрузить Markdown', () => unawaited(export(true))),
          action('Выгрузить JSON', () => unawaited(export(false))),
        ],
      ),
      ...studyList(doc['conflicts']).map(
        (c) => card([
          const Text('Конфликт правок'),
          Text(
            'Моя версия: ${c['value']['note'] ?? c['value']['title'] ?? ''}',
          ),
          Text(
            'Серверная версия: ${c['remote']?['note'] ?? c['remote']?['title'] ?? 'Недоступна'}',
          ),
          action('Сохранить мою версию отдельно', () async {
            await save(c['entity'], {
              ...studyMap(c['value']),
              'id': studyId(),
              'revision': 0,
            });
            setState(
              () => doc['conflicts'] = studyList(
                doc['conflicts'],
              ).where((x) => x['opId'] != c['opId']).toList(),
            );
            await repo.cache('personal', doc);
          }),
          action('Принять серверную', () async {
            setState(() {
              if (c['remote'] != null)
                doc['state'] = studyUpsert(
                  state,
                  c['entity'],
                  studyMap(c['remote']),
                );
              doc['conflicts'] = studyList(
                doc['conflicts'],
              ).where((x) => x['opId'] != c['opId']).toList();
            });
            await repo.cache('personal', doc);
          }),
        ]),
      ),
      heading('Продолжить'),
      ...list('positions').map(
        (p) => ListTile(
          title: Text(p['title']),
          subtitle: Text(
            {
                  'reading': 'Читаю',
                  'deferred': 'Отложено',
                  'read': 'Прочитано',
                }[p['status']] ??
                'Читаю',
          ),
          onTap: () => unawaited(resumePosition(p)),
        ),
      ),
      heading('Подборки'),
      action('Создать подборку', () => unawaited(editCollection())),
      ...list('collections').map(
        (c) => card([
          ListTile(
            title: Text(c['title']),
            subtitle: Text(
              '${studyList(c['items']).length} элементов · ${c['description'] ?? ''}',
            ),
            onTap: () => setState(() => notebook = c),
          ),
          Wrap(
            spacing: 8,
            children: [
              action('Описание', () => unawaited(editCollection(c))),
              action(
                'Скачать',
                () => unawaited(
                  download(
                    studyList(c['items'])
                        .expand(
                          (i) => i['target'] != null
                              ? [studyMap(i['target'])]
                              : i['recordId'] != null
                              ? list('records')
                                    .where((r) => r['id'] == i['recordId'])
                                    .map((r) => studyMap(r['target']))
                              : <StudyJson>[],
                        )
                        .toList(),
                  ),
                ),
              ),
              if (repo.userId != null)
                action(
                  'Создать личный план',
                  () => unawaited(createNotebookPlan(c)),
                ),
              if (repo.userId != null)
                action(
                  'Поделиться копией',
                  () => unawaited(shareCollection(c)),
                ),
              if (repo.userId != null)
                action('Закрыть опубликованные копии', () async {
                  try {
                    await repo.request('POST', 'publish', {
                      'action': 'unpublish',
                      'id': c['id'],
                      'revision': c['revision'],
                      'expectedUserId': repo.userId,
                    });
                    notice('Опубликованные копии закрыты.');
                  } catch (e) {
                    report(e);
                  }
                }),
              action(
                'Удалить',
                () => unawaited(save('collections', c, deleted: true)),
              ),
            ],
          ),
        ]),
      ),
      if (notebook != null) ...notebookWidgets(),
      heading('Выписки, заметки и вопросы'),
      textField(
        'Поиск по цитате или записи',
        search,
        (v) => setState(() => search = v),
      ),
      choices('Метка', tag, [
        ('', 'Все'),
        ...list('records')
            .expand((r) => (r['tags'] as List? ?? []).map((t) => '$t'))
            .toSet()
            .map((v) => (v, v)),
      ], (v) => setState(() => tag = v)),
      choices('Источник', bookFilter, [
        ('', 'Все'),
        ...{
          for (final r in list('records'))
            '${r['sourceBookId'] ?? studyMap(r['target'])['id']}':
                '${r['sourceBookTitle'] ?? r['sourceTitle'] ?? studyMap(r['target'])['id']}',
        }.entries.map((e) => (e.key, e.value)),
      ], (v) => setState(() => bookFilter = v)),
      choices('Подборка', collectionFilter, [
        ('', 'Все'),
        ...list('collections').map((c) => ('${c['id']}', '${c['title']}')),
      ], (v) => setState(() => collectionFilter = v)),
      CheckboxListTile(
        title: const Text('Открытые вопросы'),
        value: questionsOnly,
        onChanged: (v) => setState(() => questionsOnly = v ?? false),
      ),
      ...notes.map(recordCard),
      heading('Загруженное'),
      ...saved.map(
        (s) => ListTile(
          title: Text(s['title']),
          subtitle: Text(
            (s['missing'] as List? ?? []).isEmpty
                ? 'Текст сохранён'
                : 'Неполная копия',
          ),
          onTap: () => unawaited(open(studyMap(s['target']))),
        ),
      ),
      action(
        'Прежний список заметок',
        () => Navigator.pushNamed(context, '/notes'),
      ),
    ];
  }

  List<Widget> notebookWidgets() {
    final items = studyList(notebook!['items']);
    return [
      heading('${notebook!['title']}'),
      action('Добавить раздел', () => unawaited(editItem(null))),
      ...items.asMap().entries.map((e) {
        final i = e.value, n = e.key;
        return card([
          Text(i['title']),
          Text('${i['comment'] ?? ''}'),
          if (i['target'] != null)
            action('Читать', () => unawaited(openItem(notebook!, i))),
          if (i['recordId'] != null)
            action('Открыть запись', () {
              final r = list(
                'records',
              ).where((r) => r['id'] == i['recordId']).firstOrNull;
              if (r != null) unawaited(editRecord(r));
            }),
          Wrap(
            spacing: 8,
            children: [
              action('Изменить', () => unawaited(editItem(i))),
              ...[-1, 1].map(
                (d) => action(d < 0 ? 'Выше' : 'Ниже', () {
                  final next = [...items];
                  final temp = next[n];
                  next[n] = next[n + d];
                  next[n + d] = temp;
                  unawaited(save('collections', {...notebook!, 'items': next}));
                }, enabled: n + d >= 0 && n + d < items.length),
              ),
              action(
                'Убрать',
                () => unawaited(
                  save('collections', {
                    ...notebook!,
                    'items': items.where((x) => x['id'] != i['id']).toList(),
                  }),
                ),
              ),
            ],
          ),
        ]);
      }),
    ];
  }

  Widget snapshotText(String raw, {int? maxLines}) {
    final text = sourceDisplay(
      raw,
    ).replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!);
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: readingTextStyle(
        context,
        churchSlavonic: RegExp(
          r'[\u0460-\u052f\u2de0-\u2dff\ua640-\ua69f\u1c80-\u1c8f]',
        ).hasMatch(raw),
      ),
    );
  }

  Widget recordCard(StudyJson r) => card([
    Text(
      r['kind'] == 'question'
          ? 'Вопрос · ${r['questionStatus'] == 'open' ? 'Открыт' : 'Разобран'}'
          : r['kind'] == 'highlight'
          ? 'Выделение'
          : 'Заметка',
    ),
    snapshotText(
      '${r['originalQuote'] ?? studyMap(r['target'])['quote'] ?? ''}',
    ),
    Text('${r['note'] ?? ''}'),
    if (repo.userId != null) NoteSharingButton(noteId: '${r['id']}'),
    Text((r['tags'] as List? ?? []).join(', ')),
    if (r['unresolved'] == true)
      const Text('Старая привязка: при открытии проверьте точное место.'),
    Wrap(
      spacing: 8,
      children: [
        action('Открыть место', () => unawaited(open(studyMap(r['target'])))),
        action('Изменить', () => unawaited(editRecord(r))),
        action('Уточнить место', () {
          setState(() => rebind = r);
          notice(
            'Откройте источник, выберите отрывок и нажмите «Привязать запись здесь».',
          );
        }),
        action('В подборку', () => unawaited(pickCollection(record: r))),
        action('Удалить', () => unawaited(save('records', r, deleted: true))),
      ],
    ),
  ]);
  TextScript get sourceScript => material?['language'] == 'cu'
      ? TextScript.church
      : material?['language'] == 'cu_gr'
      ? TextScript.civil
      : TextScript.other;
  List<Widget> reader() {
    final m = material!, blocks = studyList(m['blocks']);
    return [
      if (readingNotebook != null)
        card([
          Text('Подборка: ${readingNotebook!['title']}'),
          Wrap(
            spacing: 8,
            children: [
              for (final d in [-1, 1])
                Builder(
                  builder: (context) {
                    final items = studyList(readingNotebook!['items'])
                            .where(
                              (i) =>
                                  i['kind'] == 'source' ||
                                  i['kind'] == 'record',
                            )
                            .toList(),
                        at = items.indexWhere((i) => i['id'] == readingItemId),
                        next = at + d >= 0 && at + d < items.length
                            ? items[at + d]
                            : null;
                    return action(
                      d < 0 ? 'Предыдущий материал' : 'Следующий материал',
                      () => unawaited(openItem(readingNotebook!, next!)),
                      enabled: next != null,
                    );
                  },
                ),
            ],
          ),
        ]),
      if (stack.isNotEmpty)
        action('Назад к чтению: ${stack.last['title']}', () {
          final entry = stack.removeLast(), target = studyMap(entry['target']);
          readingNotebook = entry['context'] == null
              ? null
              : studyMap(entry['context']);
          readingItemId = entry['itemId'] ?? '';
          unawaited(open(target, remember: false));
        }),
      heading('${m['title']}'),
      ScriptCaveat(source: sourceScript),
      Text(
        '${m['author'] ?? ''} · ${m['edition'] ?? ''} · ${m['language'] ?? ''}',
      ),
      if ((m['missing'] as List? ?? []).isNotEmpty)
        Text('Текст неполный: ${(m['missing'] as List).join(', ')}'),
      Wrap(
        spacing: 8,
        children: [
          action('Закрыть текст', () => setState(() => material = null)),
          action(
            'Сохранить без сети',
            () => unawaited(download([studyMap(m['target'])])),
          ),
          action('Запомнить место', () => unawaited(position())),
        ],
      ),
      choices(
        '${readingNotebook?['id'] ?? ''}'.startsWith('book-')
            ? 'Статус книги'
            : 'Статус чтения',
        '${list('positions').where((p) => '${readingNotebook?['id'] ?? ''}'.startsWith('book-') ? p['collectionId'] == readingNotebook!['id'] : p['collectionId'] == null && studyTargetKey(studyMap(p['target'])) == studyTargetKey(studyMap(m['target']))).firstOrNull?['status'] ?? 'reading'}',
        [('reading', 'Читаю'), ('deferred', 'Отложено'), ('read', 'Прочитано')],
        (v) => unawaited(position(v)),
      ),
      ExpansionTile(
        title: const Text('Материалы и мои записи'),
        children: [
          choices('Материалы', panel, [
            ('related', 'К этому месту'),
            ('toc', 'Оглавление'),
            ('notes', 'Мои записи'),
            ('edition', 'Об издании'),
          ], (v) => setState(() => panel = v)),
          ...panelWidgets(),
          if (selected != null)
            card([
              const Text('Выбранный отрывок'),
              if (rebind != null)
                action('Привязать запись здесь', () async {
                  if (selected != null &&
                      await save('records', {
                        ...rebind!,
                        'originalQuote':
                            rebind!['originalQuote'] ??
                            rebind!['target']['quote'],
                        'originalTarget':
                            rebind!['originalTarget'] ?? rebind!['target'],
                        'target': selected,
                      })) {
                    setState(() => rebind = null);
                    notice('Место уточнено. Первоначальная выписка сохранена.');
                  }
                }),
              snapshotText('${selected!['quote'] ?? ''}', maxLines: 5),
              Wrap(
                spacing: 8,
                children: [
                  action(
                    'Выделить',
                    () => unawaited(editRecord(null, 'highlight')),
                  ),
                  action('Добавить заметку', () => unawaited(editRecord())),
                  action(
                    'Сохранить вопрос',
                    () => unawaited(editRecord(null, 'question')),
                  ),
                  action(
                    'Добавить в подборку',
                    () => unawaited(pickCollection()),
                  ),
                  action(
                    linkStart == null
                        ? 'Связать с другим материалом'
                        : 'Завершить личную связь',
                    () async {
                      if (linkStart == null) {
                        setState(() => linkStart = selected);
                        notice(
                          'Откройте второй материал, выберите отрывок и завершите личную связь.',
                        );
                      } else {
                        await save('links', {
                          'id': studyId(),
                          'revision': 0,
                          'from': linkStart,
                          'to': selected,
                          'note': '',
                        });
                        setState(() => linkStart = null);
                      }
                    },
                  ),
                  action('Скопировать ссылку на место', () {
                    unawaited(
                      Clipboard.setData(
                        ClipboardData(text: studyHref(selected!)),
                      ),
                    );
                    notice('Ссылка скопирована.');
                  }),
                ],
              ),
            ]),
        ],
      ),
      ...blocks.map((b) {
        final key = keys.putIfAbsent('${b['id']}', () => GlobalKey());
        return Container(
          key: key,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(8),
          decoration: selected?['blockId'] == b['id']
              ? BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      width: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton(
                onPressed: () => setState(() => selected = studyTargetAt(m, b)),
                child: Text(
                  b['verse'] != null
                      ? 'Стих ${b['verse']}'
                      : 'Место ${(b['index'] as int) + 1}',
                ),
              ),
              if (list('records').any(
                (r) => studyLocate(m, studyMap(r['target']))?['id'] == b['id'],
              ))
                TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => SafeArea(
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height * .8,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: list('records')
                                .where(
                                  (r) =>
                                      studyLocate(
                                        m,
                                        studyMap(r['target']),
                                      )?['id'] ==
                                      b['id'],
                                )
                                .map(recordCard)
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Мои записи к этому месту'),
                ),
              StudySourceText(
                text: '${b['text']}',
                annotations: list('records')
                    .where(
                      (r) =>
                          studyLocate(m, studyMap(r['target']))?['id'] ==
                          b['id'],
                    )
                    .map((r) => studyMap(r['target']))
                    .toList(),
                script: sourceScript,
                setting: readerScript(context),
                selectedQuote: (selected?['blockId'] == b['id'])
                    ? selected!['quote'] as String?
                    : null,
                prefix: (selected?['blockId'] == b['id'])
                    ? selected!['prefix'] as String?
                    : null,
                onSelection: (quote, offset) {
                  selected = studyTargetAt(m, b, quote: quote, offset: offset);
                },
                onFootnote: (n) => unawaited(footnote(n)),
                onAction: (action) {
                  if (action == 'collection')
                    unawaited(pickCollection());
                  else if (action == 'link') {
                    linkStart = selected;
                    notice('Выберите второй материал для личной связи.');
                  } else if (action == 'word') {
                    final q = '${selected?['quote'] ?? ''}'.trim();
                    if (q.length < 100 && q.isNotEmpty)
                      showWordSheet(context, q);
                  } else
                    unawaited(editRecord(null, action));
                },
              ),
            ],
          ),
        );
      }),
    ];
  }

  String sourceDisplay(String text) => text
      .replaceAllMapped(
        RegExp(r'\{(?:st|pl)\|([^}|]+)\|([^}]+)}'),
        (m) => m[2]!,
      )
      .replaceAllMapped(RegExp(r'\{k\|([^}]+)}'), (m) => m[1]!)
      .replaceAllMapped(
        RegExp(r'\{(\d+)}'),
        (m) => ' [сноска ${m[1]}](#study-footnote-${m[1]}) ',
      );
  List<Widget> panelWidgets() {
    final m = material!;
    if (panel == 'toc')
      return [
        if ('${readingNotebook?['id'] ?? ''}'.startsWith('book-'))
          ...studyList(readingNotebook!['items']).map(
            (i) => ListTile(
              title: Text('${i['title']}'),
              onTap: () => unawaited(openItem(readingNotebook!, i)),
            ),
          ),
        if (m['metadata']?['bookId'] != null &&
            !('${readingNotebook?['id'] ?? ''}'.startsWith('book-')))
          action(
            'Оглавление книги',
            () => unawaited(loadBook(m['metadata']['bookId'])),
          ),
        card(
          studyList(m['blocks'])
              .map(
                (b) => ListTile(
                  title: Text(
                    b['verse'] != null ? 'Стих ${b['verse']}' : '${b['text']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    setState(() => selected = studyTargetAt(m, b));
                    scrollTo(b['id']);
                  },
                ),
              )
              .toList(),
        ),
      ];
    if (panel == 'notes')
      return list('records')
          .where(
            (r) => studyMap(r['target'])['id'] == studyMap(m['target'])['id'],
          )
          .map(recordCard)
          .toList();
    if (panel == 'edition')
      return [
        card([
          Text(
            '${m['author'] ?? ''}\n${m['edition'] ?? ''}\nЯзык: ${m['language'] ?? ''}',
          ),
          if (m['source'] != null) SelectableText('${m['source']}'),
          Text('${studyMap(m['metadata'])['description'] ?? ''}'),
          Text(
            'Состояние текста: ${studyMap(m['metadata'])['readiness'] ?? 'по данным издания'}',
          ),
          ...(m['footnotes'] as List? ?? []).asMap().entries.map(
            (e) => ExpansionTile(
              title: Text('Сноска ${e.key + 1}'),
              children: [
                ReadingMarkdown(sourceDisplay('${e.value}'), scrollable: false),
                action('Назад к чтению', () {
                  if (selected?['blockId'] != null)
                    scrollTo(selected!['blockId']);
                }),
              ],
            ),
          ),
        ]),
      ];
    if (related == null) return [const Text('Загружаю подготовленные связи…')];
    final rel = related!;
    return [
      Text('${rel['notice'] ?? ''}'),
      action('Связи выбранного места', () async {
        try {
          final r = await repo.public(
            'related',
            body: {'target': selected},
            key: 'related:${jsonEncode(selected)}',
          );
          if (mounted) setState(() => related = r);
        } catch (e) {
          report(e);
        }
      }),
      if (rel['relationVersion'] != 2 && studyList(rel['relations']).isNotEmpty)
        const Text('Связи этой сохранённой копии нужно обновить.'),
      ...studyList(rel['relations']).where((r) => r['other'] != null).map((r) {
        final target = studyMap(r['other']);
        return card([
          Text(
            {
                  'scripture': 'Писание',
                  'commentary': 'Толкования',
                  'citation': 'Цитируется в текстах',
                  'topic': 'По теме',
                  'alignment': 'Другая редакция',
                }[r['kind']] ??
                'Связь',
          ),
          Text('${r['title']}'),
          Text('${r['reason']}'),
          Text('${r['author']} · ${r['locator']}'),
          action('Читать источник', () => unawaited(open(target))),
          if (r['kind'] == 'alignment')
            action('Сопоставить фрагменты', () => unawaited(compare(r))),
        ]);
      }),
      if (studyList(rel['echoes']).isNotEmpty)
        heading('Цитируется в песнопениях'),
      ...studyList(rel['echoes']).map(
        (e) => card([
          Text('${e['position']} · ${e['memory']}'),
          Text(studyList(e['snippet']).map((p) => p['text']).join('')),
          action(
            'Читать песнопение',
            () => unawaited(
              open({
                'kind': 'chant',
                'id': '${e['id']}',
                if (e['sourceBook'] != null) 'edition': e['sourceBook'],
              }),
            ),
          ),
        ]),
      ),
      if (studyList(rel['scripture']).isNotEmpty) heading('Писание'),
      ...studyList(rel['scripture']).map(
        (c) => action(
          '${c['canonRef']}',
          () => unawaited(
            open({
              'kind': 'bible',
              'id': c['canonId'],
              'chapter': c['chapter'],
              'verseFrom': c['verse'],
              'verseTo': c['verse'],
              'edition': 'cs-eliz',
            }),
          ),
        ),
      ),
      if (studyMap(rel['memory'])['memory'] != null)
        action(
          'Память: ${studyMap(studyMap(rel['memory'])['memory'])['title']}',
          () => Navigator.pushNamed(
            context,
            '/saints',
            arguments:
                studyMap(studyMap(rel['memory'])['memory'])['slug'] ??
                studyMap(studyMap(rel['memory'])['memory'])['dneslovId'],
          ),
        ),
      ...studyList(studyMap(studyMap(rel['memory'])['memory'])['siblings']).map(
        (t) => action(
          t['name'],
          () => unawaited(open({'kind': 'text', 'id': t['id']})),
        ),
      ),
      if (studyList(rel['places']).isNotEmpty) heading('Места'),
      ...studyList(rel['places']).map(
        (p) => action(
          '${p['name']}',
          () => Navigator.pushNamed(context, '${p['href']}'),
        ),
      ),
      if (studyList(rel['editions']).length > 1)
        heading('Другие редакции произведения'),
      ...studyList(rel['editions']).map(
        (e) => action(
          '${e['title']} · ${e['language']} · отдельное оглавление',
          () => unawaited(loadBook(e['id'])),
        ),
      ),
      heading('Мои связи'),
      ...list('links')
          .where(
            (l) =>
                studyTargetKey(studyMap(l['from'])) ==
                    studyTargetKey(studyMap(m['target'])) ||
                studyTargetKey(studyMap(l['to'])) ==
                    studyTargetKey(studyMap(m['target'])),
          )
          .map(
            (l) => card([
              Text(
                l['note'].toString().isEmpty
                    ? 'Личное сопоставление'
                    : '${l['note']}',
              ),
              action(
                'Первый фрагмент',
                () => unawaited(open(studyMap(l['from']))),
              ),
              action(
                'Второй фрагмент',
                () => unawaited(open(studyMap(l['to']))),
              ),
              action('Комментарий', () => unawaited(editLink(l))),
            ]),
          ),
    ];
  }

  Future<void> compare(StudyJson relation) async {
    try {
      if (relation['status'] != 'checked' || relation['kind'] != 'alignment')
        throw Exception('Соответствие фрагментов не подтверждено.');
      final gen = generation,
          targets = [studyMap(relation['from']), studyMap(relation['to'])];
      final pair = await Future.wait(targets.map(repo.material));
      if (!mounted || gen != generation) return;
      if (List.generate(
        2,
        (i) =>
            targets[i]['blockId'] != null &&
            studyLocate(pair[i], targets[i]) != null,
      ).contains(false))
        throw Exception('Источник изменился: соответствие пока недоступно.');
      final controllers = [ScrollController(), ScrollController()];
      Widget part(int i) {
        final blocks = studyList(pair[i]['blocks']),
            found = studyLocate(pair[i], targets[i])!,
            start = blocks.indexWhere((b) => b['id'] == found['id']),
            end = blocks.indexWhere(
              (b) => b['id'] == (targets[i]['endBlockId'] ?? found['id']),
            );
        return SingleChildScrollView(
          controller: controllers[i],
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${pair[i]['title']} · ${pair[i]['edition']}'),
              ...blocks
                  .sublist(
                    (start - 1).clamp(0, blocks.length),
                    (end + 2).clamp(0, blocks.length),
                  )
                  .map(
                    (b) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: ReadingMarkdown(
                        sourceDisplay('${b['text']}'),
                        scrollable: false,
                      ),
                    ),
                  ),
            ],
          ),
        );
      }

      await showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(title: Text('${relation['title']}')),
            body: Column(
              children: [
                Text('${relation['locator']}'),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => c.maxWidth >= 750
                        ? Row(
                            children: [
                              Expanded(child: part(0)),
                              Expanded(child: part(1)),
                            ],
                          )
                        : DefaultTabController(
                            length: 2,
                            child: Column(
                              children: [
                                TabBar(
                                  tabs: [
                                    for (final m in pair)
                                      Tab(
                                        text: '${m['edition'] ?? m['title']}',
                                      ),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    children: [part(0), part(1)],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (final c in controllers) c.dispose();
    } catch (e) {
      report(e);
    }
  }

  Future<void> footnote(int number) async {
    final notes = material?['footnotes'] as List? ?? [];
    final base = (studyMap(material?['metadata'])['footnoteBase'] as num? ?? 1)
        .toInt();
    if (number < base || number - base >= notes.length) {
      notice('Текст этой сноски пока не подготовлен.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Сноска $number'),
        content: SingleChildScrollView(
          child: ReadingMarkdown(
            sourceDisplay('${notes[number - base]}'),
            scrollable: false,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Назад к чтению'),
          ),
        ],
      ),
    );
  }

  Future<void> editLink(StudyJson l) async {
    var note = '${l['note'] ?? ''}';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Личное сопоставление'),
        content: textField('Комментарий', note, (v) => note = v, lines: 5),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              if (await save('links', {...l, 'note': note}) && context.mounted)
                Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Библиотека'),
        actions: [
          if (material != null)
            ScriptToggle(
              source: sourceScript,
              onChanged: () => setState(() {}),
            ),
          IconButton(
            tooltip: 'Настроить чтение',
            icon: const Icon(Icons.text_fields),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          if (material != null)
            IconButton(
              tooltip: 'На службе',
              icon: const Icon(Icons.nightlight_outlined),
              onPressed: () {
                unawaited(serviceMode.setEnabled(!serviceMode.value));
                setState(() {});
              },
            ),
          IconButton(
            tooltip: 'Обновить данные входа',
            onPressed: () => unawaited(boot()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: PinchZoom(
        child: ServiceReadingScope(
          child: Column(
            children: [
              if (busy) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final (key, title) in [
                      ('catalog', 'Каталог'),
                      ('mine', 'Моё чтение'),
                      ('topics', 'Изучить тему'),
                    ])
                      ChoiceChip(
                        label: Text(title),
                        selected: tab == key,
                        onSelected: (_) => setState(() {
                          tab = key;
                          material = null;
                          book = null;
                          notebook = null;
                          search = '';
                        }),
                      ),
                  ],
                ),
              ),
              if (message.isNotEmpty || error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    error.isNotEmpty ? error : message,
                    style: TextStyle(
                      color: error.isNotEmpty
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
              Expanded(
                child: !ready
                    ? const Center(child: Text('Загружаю библиотеку…'))
                    : SingleChildScrollView(
                        controller: scroll,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (repo.userId == null)
                              const Text(
                                'Записи сохраняются на этом устройстве. Войдите для синхронизации.',
                              )
                            else
                              Wrap(
                                spacing: 8,
                                children: [
                                  action(
                                    'Синхронизировать',
                                    () => unawaited(sync()),
                                  ),
                                  action('Перенести гостевые записи', () async {
                                    try {
                                      final next = await repo.transfer(doc);
                                      if (mounted) setState(() => doc = next);
                                      notice(
                                        'Гостевые записи перенесены без замены существующих.',
                                      );
                                    } catch (e) {
                                      report(e);
                                    }
                                  }),
                                ],
                              ),
                            if (material != null)
                              ...reader()
                            else if (tab == 'catalog')
                              ...catalogue()
                            else if (tab == 'topics')
                              ...topics()
                            else
                              ...mine(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
