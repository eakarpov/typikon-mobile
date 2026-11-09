import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/prayer_circle.dart';
import '../store/prayer_circle.dart';
import '../store/store.dart';
import '../store/rule_marks.dart';
import '../store/communion_plan.dart';
import '../utils/rule_reminders.dart';
import '../utils/reading_style.dart';
import '../components/fusion_text.dart';
import '../components/reading_markdown.dart';
import '../components/pinch_zoom.dart';
import '../components/service_reading_scope.dart';
import '../components/table_of_contents.dart';
import 'prayer_circle_editor.dart';

class PrayerCircleRuleDropdown extends StatelessWidget {
  final String value;
  final List<CircleJson> variants;
  final CircleJson? catalog;
  final ValueChanged<String?>? onChanged;
  const PrayerCircleRuleDropdown({
    super.key,
    required this.value,
    required this.variants,
    this.catalog,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    isExpanded: true,
    initialValue: value,
    decoration: const InputDecoration(labelText: 'Правило на эту часть дня'),
    items: [
      const DropdownMenuItem(
        value: 'personal-heading',
        enabled: false,
        child: Text('Мои варианты'),
      ),
      ...variants.map(
        (v) => DropdownMenuItem(
          value: v['id'] as String,
          child: Text(v['title'] as String),
        ),
      ),
      if (catalog != null)
        const DropdownMenuItem(
          value: 'catalog-heading',
          enabled: false,
          child: Text('Готовые последования'),
        ),
      if (catalog != null)
        ...circlePresets(catalog!).map(
          (t) => DropdownMenuItem(
            value: 'template:${t['id']}',
            child: Text(t['title'] as String),
          ),
        ),
    ],
    onChanged: onChanged,
  );
}

class PrayerCirclePage extends StatefulWidget {
  const PrayerCirclePage({super.key});
  @override
  State<PrayerCirclePage> createState() => _PrayerCirclePageState();
}

class _PrayerCirclePageState extends State<PrayerCirclePage>
    with WidgetsBindingObserver {
  PrayerCircleRepository? repo;
  CircleJson? doc, catalog, preview;
  String? error;
  String date = '';
  String lastCurrentCycle = '';
  StreamSubscription<dynamic>? authSubscription;
  bool busy = false;
  int generation = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
    authSubscription = appStore?.onChange.listen((_) {
      if (mounted && repo?.userId != appStore?.state.auth.userId) {
        unawaited(load());
      }
    });
    timer = Timer.periodic(const Duration(seconds: 30), (_) => checkCycle());
  }

  @override
  void dispose() {
    timer?.cancel();
    authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (repo?.userId != appStore?.state.auth.userId) {
        unawaited(load());
      } else {
        checkCycle();
      }
    }
  }

  void checkCycle() {
    if (doc == null || !mounted) return;
    final key = circleCycleKey(
      DateTime.now(),
      circleMap(circleMap(doc!['state'])['config'])['timeZone'] as String,
    );
    if (key != lastCurrentCycle) {
      final old = lastCurrentCycle;
      lastCurrentCycle = key;
      if (date != old) return;
      setState(() => date = key);
      unawaited(assemble());
    }
  }

  CircleJson get state => circleMap(doc?['state']);
  CircleJson get cycle => ensureCircleCycle(circleCopy(state), date);
  Future<void> load({bool discard = false}) async {
    final gen = ++generation;
    setState(() {
      busy = true;
      error = null;
      preview = null;
      doc = null;
    });
    final r = PrayerCircleRepository(appStore?.state.auth.userId);
    repo = r;
    try {
      if (discard) {
        final p = await r.load();
        p['queue'] = [];
        await r.save(p);
      }
      final d = await r.load();
      final config = circleMap(circleMap(d['state'])['config']);
      if (!mounted || gen != generation) return;
      setState(() {
        doc = d;
        date = circleCycleKey(DateTime.now(), config['timeZone'] as String);
      });
      lastCurrentCycle = date;
      try {
        final c = await r.catalog();
        if (mounted && gen == generation) setState(() => catalog = c);
      } catch (e) {
        if (mounted && gen == generation)
          setState(() => error = 'Каталог недоступен: $e');
      }
      await assemble();
    } catch (e) {
      if (mounted && gen == generation) setState(() => error = '$e');
    } finally {
      if (mounted && gen == generation) setState(() => busy = false);
    }
  }

  Future<void> assemble() async {
    if (doc == null) return;
    final r = repo!, owner = r.userId, key = date, gen = generation;
    try {
      final p = await r.preview(state, key);
      if (!mounted ||
          gen != generation ||
          owner != appStore?.state.auth.userId ||
          key != date)
        return;
      setState(() => preview = p);
    } catch (e) {
      if (mounted && gen == generation)
        setState(() => error = 'Не удалось собрать круг: $e');
    }
  }

  Future<void> operation(
    String action,
    CircleJson values, {
    bool rebuild = false,
  }) async {
    if (doc == null || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await repo!.operation(doc!, date, action, values);
      if (!mounted) return;
      setState(() => doc = next);
      try {
        final synced = await repo!.sync(next);
        if (mounted) setState(() => doc = synced);
      } catch (e) {
        if (mounted) setState(() => error = '$e');
      }
      if (rebuild) await assemble();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit() async {
    if (catalog == null || doc == null) return;
    final pending = circleMap(state['pending']);
    final result = await Navigator.push<CircleJson>(
      context,
      MaterialPageRoute(
        builder: (_) => PrayerCircleEditor(
          config: circleMap(pending['config'] ?? state['config']),
          catalog: catalog!,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await operation('config', result, rebuild: true);
    final config = circleMap(result['config']);
    final reminders = circleMap(config['reminders']);
    await setRuleReminder(ruleRemindMorningKey, reminders['morning'] == true);
    await setRuleReminder(ruleRemindEveningKey, reminders['evening'] == true);
    final communion = circleMap(config['communion']);
    if (communion.isNotEmpty) {
      final chosen = DateTime.parse(communion['date'] as String);
      final old = await getCommunionPlan();
      final start = chosen.subtract(Duration(days: communion['days'] as int));
      if (old?.date != chosen || old?.start != start)
        await saveCommunionPlan(
          CommunionPlan(
            start,
            chosen,
            preparationDays: communion['days'] as int,
          ),
        );
    }
  }

  Future<void> read([String? blockId]) async {
    if (preview == null || doc == null) return;
    final result = await Navigator.push<CircleJson>(
      context,
      MaterialPageRoute(
        builder: (_) => _CircleReader(
          preview: preview!,
          document: doc!,
          repository: repo!,
          cycleKey: date,
          initialBlock: blockId,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => doc = result);
      await assemble();
    }
    checkCycle();
  }

  Future<void> transfer() async {
    setState(() => busy = true);
    try {
      final next = await repo!.transfer(
        doc!,
        date,
        append: doc!['hasRemote'] == true,
      );
      if (mounted) {
        setState(() => doc = next);
        await assemble();
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Мой круг'),
      actions: [
        IconButton(
          onPressed: busy || catalog == null ? null : edit,
          icon: const Icon(Icons.tune),
          tooltip: 'Изменить состав',
        ),
      ],
    ),
    body: doc == null
        ? ListView(
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
              TextButton(
                onPressed: busy ? null : load,
                child: const Text('Повторить'),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/rule/legacy'),
                child: const Text('Открыть прежнее правило'),
              ),
            ],
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Text(
                  repo?.userId == null
                      ? 'Круг сохраняется на этом устройстве.'
                      : 'Круг связан с вашей учётной записью.',
                ),
                if (repo?.userId != null)
                  OutlinedButton(
                    onPressed: busy ? null : transfer,
                    child: Text(
                      doc!['hasRemote'] == true
                          ? 'Сохранить местный состав отдельными вариантами'
                          : 'Перенести круг в аккаунт',
                    ),
                  ),
                if (circleList(doc!['queue']).isNotEmpty) ...[
                  Text(
                    'Несинхронизированных изменений: ${circleList(doc!['queue']).length}',
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            try {
                              final d = await repo!.sync(doc!);
                              if (mounted) setState(() => doc = d);
                            } catch (e) {
                              if (mounted) setState(() => error = '$e');
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: const Text('Синхронизировать'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text(
                                  'Загрузить круг из аккаунта?',
                                ),
                                content: const Text(
                                  'Местные несинхронизированные изменения будут отброшены. Сначала можно сохранить состав отдельными вариантами.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Отмена'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Загрузить'),
                                  ),
                                ],
                              ),
                            );
                            if (yes == true) await load(discard: true);
                          },
                    child: const Text('Загрузить аккаунт'),
                  ),
                ],
                if (state['legacyPsalterBookmark'] != null)
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/psalter/serial'),
                    child: const Text('Продолжить чтение Псалтири подряд'),
                  ),
                if (state['pending'] != null)
                  Text(
                    'Новый состав начнётся с вечера ${circleMap(state['pending'])['effectiveCycle']}.',
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Вечер ${dayLabel(DateTime.parse(date))}'),
                  subtitle: const Text(
                    'Затем утро и день следующей даты. Новый цикл — в 15:00.',
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.parse(date),
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2099, 12, 30),
                    );
                    if (d != null) {
                      setState(() {
                        date = dayKey(d);
                        preview = null;
                      });
                      await assemble();
                    }
                  },
                ),
                if (preview != null)
                  FilledButton.icon(
                    onPressed: () => read(),
                    icon: const Icon(Icons.menu_book),
                    label: Text(
                      cycle['bookmark'] != null
                          ? 'Продолжить чтение'
                          : 'Читать последование',
                    ),
                  ),
                if (preview?['offline'] == true)
                  const Text('Сохранённая копия без сети.'),
                if (preview != null)
                  Text(
                    preview!['complete'] == true
                        ? 'Все тексты загружены и сохранены.'
                        : 'Последование загружено не полностью.',
                  ),
                for (final part in circleParts.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      part.value,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  PrayerCircleRuleDropdown(
                    key: ValueKey(
                      '$date:${part.key}:${circleMap(cycle['overrides'])[part.key]}',
                    ),
                    value:
                        (circleMap(cycle['overrides'])[part.key] ??
                                circleMap(cycle['config'])['activeId'])
                            as String,
                    variants: circleList(
                      circleMap(cycle['config'])['variants'],
                    ),
                    catalog: catalog,
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v == null) return;
                            if (v.startsWith('template:')) {
                              final t = circlePresets(
                                catalog!,
                              ).firstWhere((t) => t['id'] == v.substring(9));
                              operation('override', {
                                'part': part.key,
                                'templateId': t['id'],
                                'template': t,
                                if (t['kind'] == 'psalter')
                                  'startCursor':
                                      state['legacyPsalterCursor'] ?? 0,
                              }, rebuild: true);
                            } else {
                              operation('override', {
                                'part': part.key,
                                'variantId': v,
                              }, rebuild: true);
                            }
                          },
                  ),
                  for (final s in circleList(
                    preview?['sections'],
                  ).where((s) => circleMap(s['block'])['part'] == part.key))
                    _section(s),
                ],
                if (preview?['communion'] != null) _communion(),
                OutlinedButton(
                  onPressed: busy || catalog == null ? null : edit,
                  child: const Text('Изменить состав'),
                ),
                ExpansionTile(
                  title: const Text('Источники и редакции'),
                  children: circleList(catalog?['sources'])
                      .map(
                        (s) => ListTile(
                          title: Text(s['title'] as String),
                          subtitle: Text(
                            '${s['role'] == 'text'
                                ? 'Текст'
                                : s['role'] == 'order'
                                ? 'Порядок совершения'
                                : 'Исследование'}${s['status'] == 'verified' ? '' : ' · требуется сверка'}${s['locator'] == null ? '' : '\n${s['locator']}'}',
                          ),
                          onTap: () => launchUrl(
                            Uri.parse(s['url'] as String),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      )
                      .toList(),
                ),
                ExpansionTile(
                  title: const Text('История чтения'),
                  subtitle: const Text(
                    'Пропуски не переносятся на следующие дни',
                  ),
                  children: [
                    for (final entry in circleHistoryEntries(state))
                      ListTile(
                        title: Text(entry['date'] as String),
                        subtitle: Text(
                          entry['unopened'] == true
                              ? 'Нет сохранённых отметок'
                              : circleList(entry['blocks']).isEmpty
                              ? 'Чтения не назначены'
                              : circleList(entry['blocks'])
                                    .map(
                                      (b) =>
                                          '${b['done'] == true ? '✓' : 'Без отметки'} · ${b['title']}',
                                    )
                                    .join('\n'),
                        ),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/rule/legacy'),
                  child: const Text('Прежнее правило и настройки'),
                ),
              ],
            ),
          ),
  );
  List<CircleJson> _matchingPreparation(String blockId) {
    final read = circleList(
      preview?['rows'],
    ).where((r) => r['blockId'] == blockId && r['kind'] != 'heading').toList();
    return circleList(circleMap(preview?['communion'])['sections']).where((
      section,
    ) {
      final rows = circleList(
        section['rows'],
      ).where((r) => r['zone'] != 'opening' && r['zone'] != 'closing').toList();
      var after = 0;
      return (section['missing'] as List? ?? []).isEmpty &&
          rows.isNotEmpty &&
          rows.every((r) {
            final index = read.indexWhere(
              (row) =>
                  read.indexOf(row) >= after &&
                  (r['contentKey'] != null && row['contentKey'] != null
                      ? r['contentKey'] == row['contentKey']
                      : row['text'] == r['text'] &&
                            row['sourceBook'] == r['sourceBook'] &&
                            (row['repeatCount'] ?? 1) ==
                                (r['repeatCount'] ?? 1)),
            );
            if (index < 0) return false;
            after = index + 1;
            return true;
          });
    }).toList();
  }

  Widget _section(CircleJson s) {
    final b = circleMap(s['block']);
    final sources = circleList(catalog?['sources']);
    return Card(
      child: Column(
        children: [
          if (s['note'] != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(s['note'] as String),
            ),
          CheckboxListTile(
            title: Text(b['title'] as String),
            value: circleMap(cycle['marks'])[b['id']] == true,
            onChanged: busy
                ? null
                : (v) => operation('mark', {
                    'blockId': b['id'],
                    'done': v == true,
                    if (s['cursor'] != null) 'expectedCursor': s['cursor'],
                  }, rebuild: b['kind'] == 'psalter'),
          ),
          if (b['kind'] == 'psalter' && b['mode'] == 'continuous')
            TextButton(
              onPressed: busy || circleMap(cycle['marks'])[b['id']] != true
                  ? null
                  : () => operation('next', {
                      'blockId': b['id'],
                      'expectedCursor': s['cursor'],
                    }, rebuild: true),
              child: const Text('Читать дальше в своём темпе'),
            ),
          for (final prepared in _matchingPreparation(b['id'] as String))
            TextButton(
              onPressed: busy || circleMap(cycle['marks'])[b['id']] != true
                  ? null
                  : () => operation('communion-mark', {
                      'blockId': prepared['id'],
                      'done': true,
                    }),
              child: Text('Учесть в подготовке: ${prepared['title']}'),
            ),
          for (final m in s['missing'] as List? ?? [])
            Padding(padding: const EdgeInsets.all(8), child: Text('$m')),
          for (final change in circleList(s['changes']))
            ExpansionTile(
              title: Text(change['label'] as String? ?? 'Календарная замена'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(change['citation'] as String? ?? ''),
                ),
              ],
            ),
          for (final id in s['sources'] as List? ?? [])
            ...sources
                .where((src) => src['id'] == id)
                .map(
                  (src) => ListTile(
                    dense: true,
                    title: Text('Источник: ${src['title']}'),
                    onTap: () => launchUrl(Uri.parse(src['url'] as String)),
                  ),
                ),
          TextButton(
            onPressed: () => read(b['id'] as String),
            child: const Text('Читать'),
          ),
          if (b['kind'] == 'reading-plan')
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/reading-plan'),
              child: const Text('Открыть план и перейти к следующему чтению'),
            ),
        ],
      ),
    );
  }

  Widget _communion() {
    final c = circleMap(preview!['communion']);
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('Подготовка к Причащению · ${c['date']}'),
            subtitle: Text('Дней подготовки: ${c['days']}'),
          ),
          for (final s in circleList(c['sections']))
            ExpansionTile(
              title: Text(s['title'] as String),
              children: [
                for (final m in s['missing'] as List? ?? []) Text('$m'),
                Text('${s['date'] ?? ''} · ${circleParts[s['part']] ?? ''}'),
                if (s['due'] == true)
                  TextButton(
                    onPressed: () => read('communion:${c['date']}:${s['id']}'),
                    child: const Text('Читать в общем последовании'),
                  )
                else
                  const Text('Откройте круг на назначенную дату для чтения.'),
                CheckboxListTile(
                  title: const Text('Прочитано'),
                  value:
                      circleMap(
                        cycle['marks'],
                      )['communion:${c['date']}:${s['id']}'] ==
                      true,
                  onChanged: busy
                      ? null
                      : (v) => operation('communion-mark', {
                          'blockId': s['id'],
                          'done': v == true,
                        }),
                ),
              ],
            ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/communion'),
            child: const Text('Дата и напоминания подготовки'),
          ),
        ],
      ),
    );
  }
}

class _CircleReader extends StatefulWidget {
  final CircleJson preview, document;
  final PrayerCircleRepository repository;
  final String cycleKey;
  final String? initialBlock;
  const _CircleReader({
    required this.preview,
    required this.document,
    required this.repository,
    required this.cycleKey,
    this.initialBlock,
  });
  @override
  State<_CircleReader> createState() => _CircleReaderState();
}

class _CircleReaderState extends State<_CircleReader> {
  late CircleJson doc;
  String? error;
  bool busy = false;
  final anchors = <String, GlobalKey>{};
  StreamSubscription<dynamic>? ownerSubscription;
  CircleJson get cycle =>
      ensureCircleCycle(circleCopy(circleMap(doc['state'])), widget.cycleKey);
  List<CircleJson> get rows => circleList(widget.preview['rows']);
  GlobalKey anchor(String id) => anchors.putIfAbsent(id, () => GlobalKey());
  @override
  void initState() {
    super.initState();
    doc = circleCopy(widget.document);
    ownerSubscription = appStore?.onChange.listen((_) {
      if (mounted && widget.repository.userId != appStore?.state.auth.userId)
        Navigator.pop(context);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.preview['bookmarkMissing'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сохранённое место недоступно после изменения текста. Выберите новое место.',
            ),
          ),
        );
      }
      final id = widget.initialBlock == null
          ? (widget.preview.containsKey('bookmark')
                    ? widget.preview['bookmark']
                    : cycle['bookmark'])
                as String?
          : '${widget.initialBlock}:heading';
      if (id != null) jump(id);
    });
  }

  @override
  void dispose() {
    ownerSubscription?.cancel();
    super.dispose();
  }

  void jump(String id) {
    final target = anchors[id]?.currentContext;
    if (target != null)
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 250),
      );
  }

  Future<void> op(String action, CircleJson values) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final d = await widget.repository.operation(
        doc,
        widget.cycleKey,
        action,
        values,
      );
      if (mounted) setState(() => doc = d);
      try {
        final synced = await widget.repository.sync(d);
        if (mounted) setState(() => doc = synced);
      } catch (e) {
        if (mounted) setState(() => error = '$e');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) Navigator.pop(context, doc);
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Келейное последование'),
        actions: [
          IconButton(
            tooltip: 'Оглавление',
            icon: const Icon(Icons.list),
            onPressed: () => showTableOfContents(
              context,
              rows
                  .where((r) => r['kind'] == 'heading')
                  .map(
                    (r) => TocEntry(
                      title: r['text'] as String,
                      anchorKey: anchor(r['id'] as String),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
      body: ServiceReadingScope(
        child: PinchZoom(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) Text(error!),
                if (widget.preview['complete'] != true)
                  const Text(
                    'Часть текстов недоступна. Список недостающего — на экране круга.',
                  ),
                for (final r in rows) _row(r),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _row(CircleJson r) {
    final id = r['id'] as String;
    final blockId = r['blockId'] as String?;
    final repeat = r['repeatCount'] as int? ?? 1;
    final b = circleBlocks(cycle).where((b) => b['id'] == blockId).firstOrNull;
    final countable =
        b != null &&
        ['jesus', 'bogorodichnoe'].contains(b['key']) &&
        repeat > 1;
    return Padding(
      key: anchor(id),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r['kind'] == 'heading') ...[
            Text(
              r['text'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (blockId != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Прочитано'),
                value: circleMap(cycle['marks'])[blockId] == true,
                onChanged: busy
                    ? null
                    : (v) => op('mark', {
                        'blockId': blockId,
                        'done': v == true,
                        if (b?['kind'] == 'psalter' &&
                            b?['mode'] == 'continuous')
                          'expectedCursor':
                              circleList(widget.preview['sections'])
                                  .where(
                                    (s) =>
                                        circleMap(s['block'])['id'] == blockId,
                                  )
                                  .firstOrNull?['cursor'],
                      }),
              ),
          ] else ...[
            if (r['label'] != null)
              Text(
                r['label'] as String,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (r['note'] != null)
              Text(
                r['note'] as String,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            if (r['kind'] == 'rubric')
              Text(
                (r['text'] as String).replaceAllMapped(
                  RegExp(r'\{k\|([^}]*)\}'),
                  (m) => m[1]!,
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontStyle: FontStyle.italic,
                ),
              )
            else if (r['markdown'] == true)
              ReadingMarkdown(r['text'] as String, scrollable: false)
            else
              FusionTextWidgets(
                text: r['text'] as String,
                footnotes: List<String>.from(r['footnotes'] as List? ?? []),
                fontFamily: circleMap(cycle['config'])['readerFont'] == 'church'
                    ? 'Monomakh'
                    : circleMap(cycle['config'])['readerFont'] == 'civil'
                    ? 'OldStandard'
                    : r['language'] == 'cu'
                    ? 'Monomakh'
                    : 'OldStandard',
              ),
            if (repeat > 1)
              Text('Повторить $repeat раз', style: readingTextStyle(context)),
            if (countable)
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed:
                        busy ||
                            (circleMap(cycle['counters'])[blockId] as int? ??
                                    0) >=
                                repeat
                        ? null
                        : () => op('counter', {
                            'blockId': blockId,
                            'count':
                                (circleMap(cycle['counters'])[blockId]
                                        as int? ??
                                    0) +
                                1,
                          }),
                    child: Text(
                      'Счётчик: ${circleMap(cycle['counters'])[blockId] ?? 0} / $repeat',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => op('counter', {'blockId': blockId, 'count': 0}),
                    child: const Text('Сбросить'),
                  ),
                ],
              ),
            if (r['poklon'] != null && r['poklon'] != false)
              Text(
                r['poklon'] is String ? r['poklon'] as String : 'Поклон',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy ? null : () => op('bookmark', {'rowId': id}),
                icon: const Icon(Icons.bookmark_outline, size: 18),
                label: Text(
                  cycle['bookmark'] == id
                      ? 'Место сохранено'
                      : 'Сохранить место',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
