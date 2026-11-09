import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:url_launcher/url_launcher.dart';
import '../domain/companion.dart';
import '../store/companion.dart';
import '../store/store.dart';
import '../utils/reading_style.dart';
import '../utils/service_mode.dart';
import '../components/service_reading_scope.dart';
import '../components/selection_menu.dart';
import '../components/word_sheet.dart';
import '../components/fusion_text.dart';

class CompanionPage extends StatefulWidget {
  final CompanionJson? initialSelection;
  final CompanionRepository? repository;
  const CompanionPage({super.key, this.initialSelection, this.repository});
  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage>
    with WidgetsBindingObserver {
  CompanionRepository? repo;
  CompanionJson? catalog, day, bundle, doc, lastViewed;
  String viewSignature = '';
  late CompanionJson selection;
  CompanionJson? opened;
  int serviceIndex = 0, nodeIndex = 0, generation = 0;
  String phase = 'before',
      error = '',
      message = '',
      phrase = '',
      focusLine = '';
  bool busy = false;
  final lineKeys = <String, GlobalKey>{};
  StreamSubscription? subscription;
  CompanionJson get state => companionMap(doc?['state']);
  CompanionJson get entries => companionMap(state['entries']);
  List<CompanionJson> get services => companionList(bundle?['services']);
  CompanionJson get service => services.isEmpty
      ? {}
      : services[serviceIndex.clamp(0, services.length - 1)];
  List<CompanionJson> get nodes => companionList(service['nodes']);
  CompanionJson get node =>
      nodes.isEmpty ? {} : nodes[nodeIndex.clamp(0, nodes.length - 1)];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selection =
        widget.initialSelection ??
        {
          'mode': 'day',
          'date': DateTime.now().toIso8601String().substring(0, 10),
        };
    unawaited(boot());
    subscription = appStore?.onChange.listen((s) {
      if (repo != null && repo!.userId != s.auth.userId) unawaited(boot());
    });
  }

  @override
  void dispose() {
    generation++;
    subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed &&
        repo != null &&
        repo!.userId != appStore?.state.auth.userId)
      unawaited(boot());
  }

  Future<void> boot() async {
    final gen = ++generation;
    setState(() {
      busy = true;
      bundle = null;
      lastViewed = null;
      viewSignature = '';
      error = '';
      message = '';
    });
    final r =
        widget.repository ?? CompanionRepository(appStore?.state.auth.userId);
    repo = r;
    try {
      final c = await r.catalog();
      final d = await r.load();
      final last = await r.lastViewed();
      if (!mounted || gen != generation) return;
      setState(() {
        catalog = c;
        doc = d;
        lastViewed = last;
      });
      if (selection['mode'] == 'day')
        await loadDay();
      else
        selection['ordo'] ??= companionList(c['services']).firstOrNull?['id'];
    } catch (e) {
      if (mounted && gen == generation) setState(() => error = '$e');
    } finally {
      if (mounted && gen == generation) setState(() => busy = false);
    }
  }

  Future<void> loadDay() async {
    final gen = generation;
    try {
      final d = await repo!.day(
        selection['date'] as String,
        selection['ustav'] as String?,
      );
      if (!mounted || gen != generation) return;
      setState(() {
        day = d;
        final variants = companionList(d['variants']);
        if (!variants.any((v) => v['key'] == selection['variant']))
          selection['variant'] = variants.firstOrNull?['key'];
        selection['service'] ??= availableServices.firstOrNull?['key'];
        selection['part'] ??= availableServices
            .where((s) => s['key'] == selection['service'])
            .firstOrNull?['part'];
      });
    } catch (e) {
      if (mounted && gen == generation)
        setState(
          () => message =
              'Службы дня недоступны. Можно открыть сохранённое последование. $e',
        );
    }
  }

  CompanionJson get variant =>
      companionList(
        day?['variants'],
      ).where((v) => v['key'] == selection['variant']).firstOrNull ??
      {};
  List<CompanionJson> get availableServices =>
      companionList(variant['stoyaniya'])
          .expand(
            (slot) => companionList(slot['services']).map(
              (s) => {
                ...s,
                'civil': slot['civil'],
                'part': slot['key'],
                'partLabel': slot['part_label'],
              },
            ),
          )
          .toList();
  Future<void> load({
    CompanionJson? chosen,
    bool resume = false,
    CompanionJson? restoreEntry,
  }) async {
    if (repo == null) return;
    final gen = generation;
    setState(() {
      busy = true;
      error = '';
      message = '';
    });
    try {
      final sel = chosen ?? selection;
      final b = await repo!.assemble(sel);
      if (!mounted || gen != generation) return;
      if (b.services.isEmpty)
        throw StateError('Эта служба не назначена в выбранном варианте дня.');
      setState(() {
        bundle = b.data;
        selection = companionCopy(sel);
        opened = companionCopy(sel);
        serviceIndex = 0;
        phase = resume ? 'during' : 'before';
        final s = b.services.first,
            old = restoreEntry ?? companionMap(entries[s['sessionKey']]),
            found = companionRestore(s, old);
        nodeIndex = found == null
            ? 0
            : companionList(
                s['nodes'],
              ).indexWhere((n) => n['id'] == found['id']);
        focusLine = found == null ? '' : old['lineId'] as String? ?? '';
        if (resume) scrollFocus();
        if (old.isNotEmpty && found == null)
          message =
              'Текст или состав изменился. Точное сохранённое место не восстановлено.';
      });
    } catch (e) {
      if (mounted && gen == generation) setState(() => error = '$e');
    } finally {
      if (mounted && gen == generation) setState(() => busy = false);
    }
  }

  Future<void> record(
    String action,
    CompanionJson n, {
    bool? done,
    CompanionJson? line,
  }) async {
    if (busy || doc == null || service.isEmpty) return;
    final gen = generation;
    setState(() => busy = true);
    try {
      final next = await repo!.operate(
        doc!,
        action,
        companionEntry(
          service,
          opened ?? selection,
          n,
          line:
              line ??
              companionList(
                n['lines'],
              ).where((l) => l['id'] == focusLine).firstOrNull,
        ),
        done: done,
      );
      if (!mounted || gen != generation) return;
      setState(() {
        doc = next;
        if (line != null) focusLine = line['id'] as String;
        message = action == 'position'
            ? 'Место сохранено.'
            : done == true
            ? 'Часть сохранена.'
            : 'Сохранение части убрано.';
      });
      if (repo!.userId != null) {
        try {
          final synced = await repo!.sync(next);
          if (mounted && gen == generation) setState(() => doc = synced);
        } catch (e) {
          if (mounted && gen == generation)
            setState(() => message = 'Изменения сохранены на устройстве. $e');
        }
      }
    } catch (e) {
      if (mounted && gen == generation) setState(() => error = '$e');
    } finally {
      if (mounted && gen == generation) setState(() => busy = false);
    }
  }

  Future<void> reopen(CompanionJson e, {String? savedId}) async {
    if (savedId != null)
      e = {
        ...e,
        'nodeId': savedId,
        'lineId': null,
        'lineHash': null,
        'contentHash':
            companionMap(
              companionMap(e['savedDetails'])[savedId],
            )['contentHash'] ??
            '',
      };
    final gen = generation;
    final b = await repo!.cached(e['key'] as String);
    if (!mounted || gen != generation) return;
    if (b == null) {
      await load(
        chosen: companionMap(e['selection']),
        resume: true,
        restoreEntry: e,
      );
      return;
    }
    setState(() {
      bundle = b.data;
      selection = companionMap(e['selection']);
      opened = companionCopy(selection);
      serviceIndex = b.services.indexWhere((s) => s['sessionKey'] == e['key']);
      if (serviceIndex < 0) serviceIndex = 0;
      final found = companionRestore(service, e);
      nodeIndex = found == null
          ? 0
          : nodes.indexWhere((n) => n['id'] == found['id']);
      phase = 'during';
      focusLine = found == null ? '' : e['lineId'] as String? ?? '';
      scrollFocus();
      if (found == null) message = 'Точное сохранённое место не найдено.';
    });
  }

  Future<void> openFile() async {
    try {
      final f = await openFileDialog();
      if (f == null) return;
      if (await f.length() > 40 * 1024 * 1024)
        throw const FormatException('Слишком большой файл.');
      final b = CompanionBundle.fromPackage(await f.readAsBytes());
      final imported = companionImportedSelection(b.services.first);
      if (!mounted) return;
      setState(() {
        bundle = b.data;
        serviceIndex = 0;
        nodeIndex = 0;
        phase = 'before';
        selection = imported;
        opened = companionCopy(selection);
        message =
            'Материалы из файла. Их привязки и статус сборки не подтверждены проектом.';
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<fs.XFile?> openFileDialog() => fs.openFile(
    acceptedTypeGroups: const [
      fs.XTypeGroup(label: '.ordo', extensions: ['ordo', 'zip']),
    ],
  );
  void rememberView() {
    if (busy || repo == null || service.isEmpty || node.isEmpty) return;
    final signature = '${service['id']}:${node['id']}:$focusLine';
    if (signature == viewSignature) return;
    viewSignature = signature;
    final entry = companionEntry(
      service,
      opened ?? selection,
      node,
      line: companionList(
        node['lines'],
      ).where((l) => l['id'] == focusLine).firstOrNull,
    );
    lastViewed = entry;
    unawaited(repo!.rememberView(entry).catchError((Object e) {}));
  }

  void scrollFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = lineKeys[focusLine]?.currentContext;
      if (mounted && target != null)
        unawaited(Scrollable.ensureVisible(target, alignment: 0.4));
    });
  }

  Widget button(String text, VoidCallback? action) =>
      OutlinedButton(onPressed: busy ? null : action, child: Text(text));
  Widget dropdown(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    void Function(String?) changed,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      isExpanded: true,
      initialValue: items.any((i) => i.value == value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: busy ? null : changed,
    ),
  );
  Widget sources(CompanionJson note) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${note['author'] ?? 'Редакционная справка'} · ${(bundle == null || bundle?['trusted'] == true) ? 'Сверено по источнику' : 'Материалы из файла; привязки не подтверждены'} · ${note['checkedAt'] ?? ''}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      for (final ref in companionList(note['sourceRefs']))
        ...companionList(bundle?['sources'] ?? catalog?['sources'])
            .where((s) => s['id'] == ref['sourceId'])
            .map(
              (s) => TextButton(
                onPressed: () => openUrl(s['url']),
                child: Text('${s['title']} · ${ref['locator']}'),
              ),
            ),
    ],
  );
  void openUrl(dynamic raw) {
    if (raw is! String) return;
    final u = Uri.tryParse(raw);
    if (u != null && ['http', 'https'].contains(u.scheme))
      unawaited(launchUrl(u, mode: LaunchMode.externalApplication));
  }

  Widget note(CompanionJson n) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(n['summary'] as String? ?? ''),
      const SizedBox(height: 6),
      Text(n['detail'] as String? ?? ''),
      sources(n),
    ],
  );
  List<WordMeaning> meanings(String word) {
    final q = companionNormalize(word);
    return companionList(node['wordSenses'])
        .where(
          (w) => (w['forms'] as List? ?? []).any(
            (f) => companionNormalize('$f') == q,
          ),
        )
        .map((w) {
          final n = companionMap(w['explanation']);
          return WordMeaning(
            title: n['title'] as String? ?? word,
            text: '${n['summary']}\n${n['detail']}',
            source:
                '${n['author']} · ${companionList(n['sourceRefs']).map((r) => r['locator']).join('; ')}',
          );
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    rememberView();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Спутник богослужения'),
        actions: [
          IconButton(
            onPressed: busy ? null : openFile,
            icon: const Icon(Icons.file_open_outlined),
            tooltip: 'Открыть .ordo',
          ),
          IconButton(
            onPressed: () {
              unawaited(serviceMode.setEnabled(!serviceMode.value));
              setState(() {});
            },
            icon: const Icon(Icons.nightlight_outlined),
            tooltip: 'На службе',
          ),
        ],
      ),
      body: ServiceReadingScope(
        child: Material(
          color: readingBackgroundColor(context),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error.isNotEmpty)
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (error.isNotEmpty && bundle == null && catalog != null) ...[
                  const Text('Общие сведения; порядок на дату не собран.'),
                  note(
                    companionMap(
                      companionList(catalog?['services'])
                          .where(
                            (s) => selection['mode'] == 'study'
                                ? s['id'] == selection['ordo']
                                : s['service'] == selection['service'],
                          )
                          .firstOrNull?['guide'],
                    ),
                  ),
                ],
                if (message.isNotEmpty) Text(message),
                if (busy) const LinearProgressIndicator(),
                Wrap(
                  spacing: 8,
                  children: [
                    button('Служба на дату', () {
                      setState(() {
                        selection['mode'] = 'day';
                        selection['date'] ??= DateTime.now()
                            .toIso8601String()
                            .substring(0, 10);
                      });
                      unawaited(loadDay());
                    }),
                    button(
                      'Изучить службу',
                      () => setState(() {
                        selection['mode'] = 'study';
                        selection['ordo'] ??= companionList(
                          catalog?['services'],
                        ).firstOrNull?['id'];
                      }),
                    ),
                    button(
                      'Сохранённое',
                      () => setState(() => phase = 'after'),
                    ),
                  ],
                ),
                if (repo?.userId == null)
                  const Text(
                    'Сохранения на этом устройстве. Войдите для синхронизации.',
                  )
                else
                  Wrap(
                    children: [
                      button('Синхронизировать', () async {
                        try {
                          final d = await repo!.sync(doc!);
                          if (mounted) setState(() => doc = d);
                        } catch (e) {
                          if (mounted) setState(() => error = '$e');
                        }
                      }),
                      button('Перенести гостевые сохранения', () async {
                        try {
                          final d = await repo!.transferGuest(doc!);
                          if (mounted) setState(() => doc = d);
                        } catch (e) {
                          if (mounted) setState(() => error = '$e');
                        }
                      }),
                    ],
                  ),
                if (catalog != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          if (selection['mode'] == 'day') ...[
                            ListTile(
                              title: Text(
                                'Богослужебный день: ${selection['date']}',
                              ),
                              trailing: const Icon(Icons.calendar_month),
                              onTap: busy
                                  ? null
                                  : () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.parse(
                                          selection['date'],
                                        ),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime(2099, 12, 31),
                                      );
                                      if (date != null) {
                                        setState(() {
                                          selection['date'] = date
                                              .toIso8601String()
                                              .substring(0, 10);
                                          selection.remove('service');
                                          selection.remove('variant');
                                        });
                                        await loadDay();
                                      }
                                    },
                            ),
                            dropdown(
                              'Устав',
                              selection['ustav'] as String? ?? '',
                              [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('По умолчанию движка'),
                                ),
                                for (final u in companionList(
                                  catalog?['ustavy'],
                                ))
                                  DropdownMenuItem(
                                    value: u['ustav'] as String,
                                    child: Text(u['label'] as String),
                                  ),
                              ],
                              (v) {
                                setState(() {
                                  selection['ustav'] = v;
                                  selection.remove('variant');
                                  selection.remove('service');
                                });
                                unawaited(loadDay());
                              },
                            ),
                            if (day != null) ...[
                              dropdown(
                                'Вариант дня',
                                selection['variant'] as String?,
                                [
                                  for (final v in companionList(
                                    day?['variants'],
                                  ))
                                    DropdownMenuItem(
                                      value: v['key'] as String,
                                      child: Text(v['label'] as String),
                                    ),
                                ],
                                (v) {
                                  setState(() {
                                    selection['variant'] = v;
                                    selection['service'] =
                                        availableServices.firstOrNull?['key'];
                                    selection['part'] =
                                        availableServices.firstOrNull?['part'];
                                  });
                                },
                              ),
                              dropdown(
                                'Служба',
                                '${selection['part'] ?? ''}|${selection['service'] ?? ''}',
                                [
                                  for (final s in {
                                    for (final s in availableServices)
                                      '${s['part']}|${s['key']}': s,
                                  }.values)
                                    DropdownMenuItem(
                                      value: '${s['part']}|${s['key']}',
                                      child: Text(
                                        '${s['label']} · ${s['civil']} ${s['partLabel'] ?? ''}',
                                      ),
                                    ),
                                ],
                                (v) => setState(() {
                                  final parts = v!.split('|');
                                  selection['part'] = parts[0];
                                  selection['service'] = parts[1];
                                }),
                              ),
                            ],
                          ] else ...[
                            const Text(
                              'Общая книжная схема без назначения на дату. Для изменяемых текстов откройте службу на дату.',
                            ),
                            dropdown(
                              'Последование',
                              selection['ordo'] as String?,
                              [
                                for (final s in companionList(
                                  catalog?['services'],
                                ))
                                  DropdownMenuItem(
                                    value: s['id'] as String,
                                    child: Text(
                                      '${companionMap(s['guide'])['title']}: ${s['title']}',
                                    ),
                                  ),
                              ],
                              (v) => setState(() => selection['ordo'] = v),
                            ),
                          ],
                          button('Открыть Спутник', () => unawaited(load())),
                        ],
                      ),
                    ),
                  ),
                if (phase == 'after') ...[
                  Text(
                    'Вернуться к услышанному',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (lastViewed != null)
                    button(
                      'Последняя открытая: ${lastViewed!['title']} · ${lastViewed!['nodeTitle']}',
                      () => unawaited(reopen(lastViewed!)),
                    ),
                  for (final e in entries.values) ...[
                    ListTile(
                      title: Text('${e['title']}'),
                      subtitle: Text(
                        '${e['nodeTitle']} · сохранённых частей: ${companionMap(e['saved']).values.where((v) => v == true).length}',
                      ),
                      onTap: () => unawaited(reopen(companionMap(e))),
                      trailing: IconButton(
                        tooltip: 'Убрать из истории',
                        icon: const Icon(Icons.close),
                        onPressed: busy
                            ? null
                            : () async {
                                final d = await repo!.operate(
                                  doc!,
                                  'remove',
                                  companionMap(e),
                                );
                                if (mounted) setState(() => doc = d);
                              },
                      ),
                    ),
                    for (final item in companionMap(
                      e['saved'],
                    ).entries.where((v) => v.value == true))
                      ListTile(
                        leading: const Icon(Icons.bookmark),
                        title: Text(
                          '${companionMap(companionMap(e['savedDetails'])[item.key])['title'] ?? 'Сохранённая часть'}',
                        ),
                        onTap: () => unawaited(
                          reopen(companionMap(e), savedId: item.key),
                        ),
                      ),
                  ],
                  if (entries.isEmpty)
                    const Text(
                      'Сохраните место или часть службы, чтобы вернуться к ней позже.',
                    ),
                ],
                if (bundle != null && service.isNotEmpty) ...[
                  Text(
                    service['title'] as String,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (services.length > 1)
                    dropdown(
                      'Стояние',
                      serviceIndex.toString(),
                      [
                        for (var i = 0; i < services.length; i++)
                          DropdownMenuItem(
                            value: '$i',
                            child: Text(
                              '${services[i]['title']} · ${services[i]['civil']} ${services[i]['partLabel']}',
                            ),
                          ),
                      ],
                      (v) => setState(() {
                        serviceIndex = int.parse(v!);
                        nodeIndex = 0;
                      }),
                    ),
                  Text(
                    (opened ?? selection)['mode'] == 'study'
                        ? 'Книжная схема, не назначение на сегодня.'
                        : 'Богослужебный день: ${(opened ?? selection)['date']}. Совершение: ${service['civil'] ?? 'не определено'} ${service['partLabel'] ?? ''}.',
                  ),
                  Text(service['assemblyStatus'] as String? ?? ''),
                  if (service['replacedBy'] != null)
                    Text(
                      'Совершение в составе: ${service['replacedBy']}. Отдельное совершение этим просмотром не назначается.',
                    ),
                  if (service['error'] != null)
                    Text('Служба не собрана: ${service['error']}'),
                  Text(
                    'Корпус ${bundle!['corpusVersion']}; пояснения ${bundle!['editorialVersion']}. ${bundle!['offline'] == true ? 'Сохранённая копия.' : ''}',
                  ),
                  Text(
                    'Порядок: ${companionMap(service['coverage'])['structure'] == true ? 'собран' : 'неполный'} · Тексты: ${companionMap(service['coverage'])['texts'] == true ? 'сохранены' : 'есть недостающие'} · Переводы: ${companionMap(service['coverage'])['translations']}/${companionMap(service['coverage'])['translationTotal']}',
                  ),
                  if (!nodes.any(
                    (n) => companionList(n['lines']).any(
                      (l) => companionList(
                        l['translations'],
                      ).any((t) => t['language'] == 'ru'),
                    ),
                  ))
                    const Text(
                      'Русский перевод этого последования не подготовлен. Объяснение смысла не является переводом.',
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      button(
                        'До службы',
                        () => setState(() => phase = 'before'),
                      ),
                      button('Во время', () {
                        setState(() => phase = 'during');
                        scrollFocus();
                      }),
                      button('После', () => setState(() => phase = 'after')),
                      button('Сохранить для чтения без сети', () async {
                        try {
                          await repo!.cacheBundle(opened ?? selection, bundle!);
                          if (mounted)
                            setState(
                              () => message =
                                  companionMap(service['coverage'])['texts'] ==
                                      true
                                  ? 'Полное последование сохранено для чтения без сети.'
                                  : 'Порядок и доступные материалы сохранены. Текст последования неполный.',
                            );
                        } catch (e) {
                          if (mounted) setState(() => error = '$e');
                        }
                      }),
                    ],
                  ),
                  if (phase == 'before') ...[
                    note(companionMap(service['guide'])),
                    ExpansionTile(
                      title: const Text('Почему сегодня так?'),
                      children: [
                        if ((opened ?? selection)['mode'] == 'study')
                          const Text(
                            'У книжной схемы нет календарного назначения.',
                          )
                        else ...[
                          for (final f in companionList(service['facts']))
                            ListTile(
                              title: Text('${f['label']}: ${f['value']}'),
                              subtitle: const Text('Данные конкретной сборки'),
                            ),
                          const Text(
                            'Применённое правило описывает работу сборщика. Его наличие не означает полной сверки календарного сочетания.',
                          ),
                          for (final r in companionList(service['rules']))
                            ListTile(
                              title: Text('${r['label']}'),
                              subtitle: Text(
                                '${r['reason'] ?? ''}\n${r['status']} ${companionList(r['sourceRefs']).map((ref) => ref['locator']).join('; ')}',
                              ),
                            ),
                        ],
                      ],
                    ),
                    for (final id
                        in companionMap(service['guide'])['furtherReading']
                                as List? ??
                            [])
                      ...companionList(bundle!['sources'])
                          .where((s) => s['id'] == id)
                          .map(
                            (s) => TextButton(
                              onPressed: () => openUrl(s['url']),
                              child: Text(
                                'Подробнее: ${s['title']} · авторское толкование',
                              ),
                            ),
                          ),
                  ],
                  if (phase != 'after') ...[
                    ExpansionTile(
                      initiallyExpanded: phase == 'before',
                      title: const Text('Карта службы'),
                      children: [
                        for (var i = 0; i < nodes.length; i++)
                          ListTile(
                            title: Text('${i + 1}. ${nodes[i]['title']}'),
                            subtitle:
                                companionMap(
                                      entries[service['sessionKey']],
                                    )['nodeId'] ==
                                    nodes[i]['id']
                                ? const Text('Ваше место')
                                : null,
                            onTap: () => setState(() {
                              nodeIndex = i;
                              phase = 'during';
                            }),
                          ),
                      ],
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Название или услышанная фраза',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => phrase = v),
                    ),
                    if (phrase.isNotEmpty) ...[
                      for (final n in companionSearchOccurrences(
                        service,
                        phrase,
                      ))
                        ListTile(
                          title: Text(n['title'] as String),
                          subtitle: Text(n['context'] as String? ?? ''),
                          onTap: () => setState(() {
                            nodeIndex = nodes.indexWhere(
                              (v) => v['id'] == n['nodeId'],
                            );
                            phase = 'during';
                            focusLine = n['lineId'] as String? ?? '';
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final target =
                                  lineKeys[n['lineId']]?.currentContext;
                              if (mounted && target != null)
                                unawaited(
                                  Scrollable.ensureVisible(
                                    target,
                                    alignment: 0.4,
                                  ),
                                );
                            });
                          }),
                        ),
                      if (companionSearchOccurrences(service, phrase).isEmpty)
                        const Text('Совпадений нет. Выберите часть на карте.'),
                    ],
                  ],
                  if (phase == 'during' && node.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        button(
                          'Назад',
                          nodeIndex <= 0
                              ? null
                              : () {
                                  setState(() => nodeIndex--);
                                  unawaited(record('position', node));
                                },
                        ),
                        button(
                          'Мы здесь',
                          () => unawaited(record('position', node)),
                        ),
                        button(
                          'Далее',
                          nodeIndex >= nodes.length - 1
                              ? null
                              : () {
                                  setState(() => nodeIndex++);
                                  unawaited(record('position', node));
                                },
                        ),
                        button(
                          companionMap(
                                    companionMap(
                                      entries[service['sessionKey']],
                                    )['saved'],
                                  )[node['id']] ==
                                  true
                              ? 'Убрать сохранение'
                              : 'Сохранить часть',
                          () => unawaited(
                            record(
                              'save',
                              node,
                              done:
                                  companionMap(
                                    companionMap(
                                      entries[service['sessionKey']],
                                    )['saved'],
                                  )[node['id']] !=
                                  true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      node['title'] as String,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (node['condition'] != null)
                      Text('Условие: ${node['condition']}'),
                    if (node['optional'] == true)
                      const Text('Условная или необязательная часть схемы.'),
                    if (node['audibleCue'] != null)
                      Text('Узнать по словам: ${node['audibleCue']}'),
                    note(companionMap(node['explanation'])),
                    ExpansionTile(
                      title: const Text('Почему это место здесь?'),
                      children: [
                        if (companionList(node['evidence']).isEmpty)
                          const Text(
                            'Отдельное проверенное основание не предоставлено.',
                          ),
                        for (final e in companionList(node['evidence']))
                          ListTile(
                            title: Text(e['text'] as String),
                            subtitle: Text(
                              e['verified'] == true
                                  ? 'Сверено с книгой'
                                  : 'Сверка основания не подтверждена',
                            ),
                          ),
                      ],
                    ),
                    if ((node['repeatCount'] as num? ?? 1) > 1)
                      Text('Повторения всей части: ${node['repeatCount']}.'),
                    for (final l in companionList(node['lines']))
                      Padding(
                        key: lineKeys.putIfAbsent(
                          '${l['id']}',
                          () => GlobalKey(),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (l['label'] != null)
                              Text(
                                l['label'] as String,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            if (l['voiced'] == 'secret')
                              const Text(
                                'Тайная молитва: текст для изучения, не слышимый ориентир.',
                              ),
                            SelectionMenu.wordsOnly(
                              extraItems: (word, container) => [
                                TextSelectionToolbarTextButton(
                                  onPressed: () => unawaited(
                                    record('position', node, line: l),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Text('Мы здесь'),
                                ),
                                TextSelectionToolbarTextButton(
                                  onPressed: () => showWordSheet(
                                    context,
                                    word,
                                    meanings: meanings(word),
                                    hasMeaningContext: true,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Text('Значение здесь'),
                                ),
                              ],
                              child: FusionTextWidgets(
                                footnotes: const [],
                                text:
                                    l['text'] as String? ??
                                    companionMissingText(l['absent']),
                                fontFamily: l['language'] == 'cu'
                                    ? 'Monomakh'
                                    : 'OldStandard',
                              ),
                            ),
                            if ((l['repeatCount'] as num? ?? 1) > 1)
                              Text('Повторить ${l['repeatCount']} раз'),
                            if (l['poklon'] != null && l['poklon'] != false)
                              Text(
                                l['poklon'] is String
                                    ? l['poklon'] as String
                                    : 'Поклон',
                              ),
                            if (l['address'] != null)
                              ExpansionTile(
                                title: const Text('Источник текста'),
                                children: [
                                  Text(
                                    '${l['editionLabel'] ?? l['edition'] ?? 'Издание не указано'} · ${l['address']}',
                                  ),
                                ],
                              ),
                            if (l['sourceUrl'] != null)
                              TextButton(
                                onPressed: () => openUrl(l['sourceUrl']),
                                child: const Text('Источник текста'),
                              ),
                            for (final t in companionList(l['translations']))
                              ExpansionTile(
                                title: Text(
                                  '${bundle?['trusted'] == true ? 'Перевод' : 'Параллель из файла, соответствие не подтверждено'} · ${t['language']} · ${t['editionLabel'] ?? t['edition']}',
                                ),
                                children: [
                                  Text(t['text'] as String),
                                  if (t['publisher'] != null ||
                                      t['year'] != null)
                                    Text(
                                      '${t['publisher'] ?? ''} ${t['year'] ?? ''}',
                                    ),
                                  Text(
                                    'Переводчик: ${t['translator'] ?? 'не указан в корпусе'}. Связь ${bundle?['trusted'] != true
                                        ? 'из файла, не подтверждена доверенным каталогом'
                                        : t['basis'] == 'edition'
                                        ? 'заявлена издателем'
                                        : 'подтверждена сверкой'}.',
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ExpansionTile(
                      title: const Text('Слова и понятия'),
                      children: [
                        for (final w in companionList(node['wordSenses']))
                          ListTile(
                            title: Text((w['forms'] as List).join(', ')),
                            subtitle: note(companionMap(w['explanation'])),
                          ),
                        const Text(
                          'Значения остальных слов в этом контексте не подготовлены.',
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
