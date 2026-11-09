import 'dart:async';
import '../domain/prayer_circle.dart';
import '../store/prayer_circle.dart';
import '../store/store.dart';
import '../components/fusion_text.dart';
import '../components/reading_markdown.dart';
import '../components/pinch_zoom.dart';
import '../components/service_reading_scope.dart';

import 'package:flutter/material.dart';

import '../components/trapeza_line.dart';
import '../store/reading_progress.dart';
import '../store/communion_plan.dart';
import '../utils/notification_permission.dart';
import '../store/rule_marks.dart';
import 'posledovanie_page.dart';

/// Три канона подготовки — каждый читается один раз.
const List<(String, String)> communionCanons = <(String, String)>[
  ("molebny-kanon-pokayanny", "Канон покаянный"),
  ("molebny-kanon-bogorodice", "Канон Богородице"),
  ("molebny-kanon-angelu-hranitelyu", "Канон Ангелу хранителю"),
];

/// Ключ последования ко Причащению и его заголовок на экране чтения.
const String koPrichashcheniyuKey = "ko-prichashcheniyu";
const String koPrichashcheniyuTitle = "Молитвы ко Причащению";

/// Ключ благодарственных молитв и их заголовок на экране чтения.
const String blagodarstvennyeKey = "blagodarstvennye";
const String blagodarstvennyeTitle = "Благодарственные молитвы";

/// На сколько дней вперёд выбирается день причащения.
const int communionHorizonDays = 40;

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Пункт раскладки: что читается и куда это открывается.
class CommunionItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? route;
  final Object? arguments;

  const CommunionItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.route,
    this.arguments,
  });
}

/// Один список подготовки независимо от расстояния до выбранной даты.
/// Пост — три предшествующих дня; чтения не размножаются по дням.
class CommunionPage extends StatefulWidget {
  /// «Сегодня». Подменяется тестами; в приложении — настоящее утро.
  final DateTime? today;

  /// Выбранный день сразу, минус диалог. Подменяется тестами; в приложении
  /// день выбирают диалогом — не раньше сегодня и не дальше сорока дней.
  final DateTime? initialDate;

  /// Строка трапезы. Подменяется тестами; в приложении — `TrapezaLine`.
  final Widget Function(DateTime date)? trapeza;

  const CommunionPage(
    BuildContext? context, {
    super.key,
    this.today,
    this.initialDate,
    this.trapeza,
  });

  @override
  State<CommunionPage> createState() => _CommunionPageState();
}

class _CommunionPageState extends State<CommunionPage> {
  late final DateTime _today;
  late DateTime _chosen;
  bool _hasPlan = false;
  bool _remind = false;
  int _days = 3;
  CircleJson? _assembled;
  String? _assemblyError;

  String _gender = "m";

  /// Отметки «прочитано» по id пункта.
  Map<String, bool> _marks = const <String, bool>{};

  /// Пункты последнего построения: тоглу прогресса нужен их состав, и просить
  /// его заново у `FutureBuilder` неоткуда.
  List<CommunionItem> _currentItems = const <CommunionItem>[];

  @override
  void initState() {
    super.initState();
    _today = _dateOnly(widget.today ?? DateTime.now());
    _chosen = _dateOnly(widget.initialDate ?? _today);
    _restorePlan();
  }

  Future<void> _restorePlan() async {
    var plan = await getCommunionPlan();
    // Старое уведомление не должно перезаписывать уже выбранный новый план.
    if (widget.initialDate != null && plan == null) {
      plan = CommunionPlan(communionPreparationStart(_chosen), _chosen);
      await saveCommunionPlan(plan);
      await updateCirclePreparation(plan);
    }
    final remind = await communionReminderEnabled();
    if (!mounted) return;
    setState(() {
      if (plan != null) {
        _chosen = plan.date;
        _days = plan.preparationDays;
        _hasPlan = true;
      }
      _remind = remind;
    });
    await _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final date = dayKey(_chosen);
    final gender = await ruleGender();
    await migrateCommunionMarks(date);
    final marks = await marksWithPrefix('communion_done:$date:');
    if (!mounted || dayKey(_chosen) != date) return;
    setState(() {
      _gender = gender;
      _marks = marks;
    });
    unawaited(_loadPrepared());
  }

  Future<void> _loadPrepared() async {
    final date = dayKey(_chosen);
    final repo = PrayerCircleRepository(appStore?.state.auth.userId);
    try {
      final config = initialCircleConfig();
      config['gender'] = _gender;
      (config['variants'] as List).first['blocks'] = <CircleJson>[];
      config['communion'] = {'date': date, 'days': _days};
      final state = initialCircleState(config);
      final preview = await repo.preview(state, date, cacheTag: 'preparation');
      if (!mounted || date != dayKey(_chosen)) return;
      setState(() {
        _assembled = circleMap(preview['communion']);
        _assemblyError = null;
      });
    } catch (_) {
      if (mounted && date == dayKey(_chosen))
        setState(
          () => _assemblyError =
              'Календарный состав недоступен. Ниже базовый список прежней версии; сезонные изменения не проверены.',
        );
    }
  }

  Future<void> _setReminder(bool value) async {
    if (value && !await ensureNotificationPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Разрешите уведомления в настройках системы.'),
        ),
      );
      return;
    }
    await setCommunionReminder(value);
    if (mounted) setState(() => _remind = value);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _chosen.isBefore(_today) ? _today : _chosen,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: communionHorizonDays)),
      locale: const Locale("ru"),
    );
    if (picked == null || !mounted) return;
    if (_hasPlan && _dateOnly(picked) == _chosen) return;
    final plan = CommunionPlan(
      DateTime(picked.year, picked.month, picked.day - _days),
      _dateOnly(picked),
      preparationDays: _days,
    );
    await saveCommunionPlan(plan);
    await updateCirclePreparation(plan);
    if (!mounted) return;
    setState(() {
      _chosen = plan.date;
      _hasPlan = true;
      _remind = false;
      _assembled = null;
    });
    unawaited(_loadPrefs());
  }

  List<CommunionItem> _items() {
    final ready = circleList(_assembled?['sections']);
    if (ready.isNotEmpty)
      return ready
          .map(
            (s) => CommunionItem(
              id: s['id'] as String,
              title: s['title'] as String,
              route: '/communion/assembled',
              arguments: s,
            ),
          )
          .toList();
    return [
      for (var i = 0; i < communionCanons.length; i++)
        CommunionItem(
          id: 'canon:$i',
          title: communionCanons[i].$2,
          route: '/canons',
          arguments: communionCanons[i].$1,
        ),
      CommunionItem(
        id: 'service',
        title: 'Последование ко Причащению',
        route: '/posledovanie',
        arguments: posledovanieRouteArgument(
          koPrichashcheniyuKey,
          'Последование ко Причащению',
          gender: _gender,
          part: PosledovaniePart.beforeCommunion,
        ),
      ),
      CommunionItem(
        id: 'prayers',
        title: koPrichashcheniyuTitle,
        route: '/posledovanie',
        arguments: posledovanieRouteArgument(
          koPrichashcheniyuKey,
          koPrichashcheniyuTitle,
          gender: _gender,
          part: PosledovaniePart.communionPrayers,
        ),
      ),
      CommunionItem(
        id: 'day:blagodarstvennye',
        title: blagodarstvennyeTitle,
        subtitle: 'после Святого Причащения',
        route: '/posledovanie',
        arguments: posledovanieRouteArgument(
          blagodarstvennyeKey,
          blagodarstvennyeTitle,
          gender: _gender,
        ),
      ),
    ];
  }

  Widget _itemTile(CommunionItem item) {
    final done = _marks[item.id] == true;
    return ListTile(
      leading: Checkbox(
        value: done,
        onChanged: (value) => unawaited(_toggle(item, value ?? false)),
      ),
      title: Text(item.title),
      subtitle: item.subtitle == null ? null : Text(item.subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: item.route == null
          ? null
          : () => Navigator.pushNamed(
              context,
              item.route!,
              arguments: item.arguments,
            ),
    );
  }

  Future<void> _toggle(CommunionItem item, bool done) async {
    final date = dayKey(_chosen);
    await setCommunionItemDone(date, item.id, done);
    await updateCirclePreparationMark(date, item.id, done);
    if (!mounted) return;
    setState(() => _marks = <String, bool>{..._marks, item.id: done});
    final total = _currentItems.length;
    final doneCount = _currentItems.where((i) => _marks[i.id] == true).length;
    // 1.0 — край: стор сам стирает запись. Так и надо: подготовка закрыта
    // галочками, а не дочитана наполовину.
    unawaited(
      saveReadingProgress(
        "communion:$date",
        total == 0 ? 0 : doneCount / total,
        name: "Причастие: ${dayLabel(_chosen)}",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPlan) {
      return Scaffold(
        appBar: AppBar(title: const Text('Причастие')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Выбрать день причащения'),
              subtitle: const Text(
                'Выберите дату, чтобы составить подготовку. '
                'Напоминания включаются отдельно.',
              ),
              onTap: _pickDate,
            ),
          ],
        ),
      );
    }
    final items = _items();
    _currentItems = items;
    final doneCount = items.where((i) => _marks[i.id] == true).length;

    final groups = <Widget>[
      _DateTile(date: _chosen, onTap: _pickDate),
      _GroupHeader(_days == 3 ? 'Три дня поста' : 'Дней подготовки: $_days'),
      for (var i = _days; i >= 1; i--) ...[
        ListTile(
          title: Text(
            'Пост · ${dayLabel(DateTime(_chosen.year, _chosen.month, _chosen.day - i))}',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: (widget.trapeza ?? (date) => TrapezaLine(date: date))(
            DateTime(_chosen.year, _chosen.month, _chosen.day - i),
          ),
        ),
      ],
      const _GroupHeader('До Причащения · прочитать один раз'),
      for (final item in items.where(
        (i) => i.id != 'thanksgiving' && i.id != 'day:blagodarstvennye',
      ))
        _itemTile(item),
      const _GroupHeader('После Причащения'),
      _itemTile(items.last),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Причастие",
          style: TextStyle(fontFamily: "OldStandard"),
        ),
      ),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LinearProgressIndicator(
                  value: items.isEmpty ? 0 : doneCount / items.length,
                ),
                const SizedBox(height: 4.0),
                Text("прочитано: $doneCount/${items.length}"),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Напоминать о подготовке'),
            subtitle: Text(
              !_hasPlan
                  ? 'Сначала выберите день причащения'
                  : !_chosen.isAfter(_today)
                  ? 'Дни подготовки завершены'
                  : 'С 21:00 в дни подготовки. Время доставки выбирает система.',
            ),
            value: _remind,
            onChanged: _hasPlan && _chosen.isAfter(_today)
                ? _setReminder
                : null,
          ),
          DropdownButtonFormField<int>(
            initialValue: _days,
            decoration: const InputDecoration(labelText: 'Дней подготовки'),
            items: List.generate(
              41,
              (n) => DropdownMenuItem(value: n, child: Text('$n')),
            ),
            onChanged: (n) async {
              if (n == null) return;
              await saveCommunionPlan(
                CommunionPlan(
                  DateTime(_chosen.year, _chosen.month, _chosen.day - n),
                  _chosen,
                  preparationDays: n,
                ),
              );
              final updatedPlan = await getCommunionPlan();
              if (updatedPlan != null)
                await updateCirclePreparation(updatedPlan);
              if (!mounted) return;
              setState(() {
                _days = n;
                _remind = false;
                _assembled = null;
              });
              unawaited(_loadPrepared());
            },
          ),
          if (_assemblyError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_assemblyError!),
            ),
          ...groups,
          const SizedBox(height: 24.0),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateTile({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.event),
      title: const Text("День причащения"),
      subtitle: Text(dayLabel(date)),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: onTap,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;

  const _GroupHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class CommunionAssembledPage extends StatelessWidget {
  final CircleJson section;
  const CommunionAssembledPage({super.key, required this.section});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(section['title'] as String? ?? 'Подготовка')),
    body: ServiceReadingScope(
      child: PinchZoom(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final missing in section['missing'] as List? ?? [])
                Text('$missing'),
              for (final row in circleList(section['rows']))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (row['label'] != null)
                        Text(
                          row['label'] as String,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      if (row['note'] != null)
                        Text(
                          row['note'] as String,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      if (row['kind'] == 'rubric')
                        Text(
                          row['text'] as String,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else if (row['markdown'] == true)
                        ReadingMarkdown(
                          row['text'] as String,
                          scrollable: false,
                        )
                      else
                        FusionTextWidgets(
                          text: row['text'] as String? ?? '',
                          footnotes: List<String>.from(
                            row['footnotes'] as List? ?? [],
                          ),
                          fontFamily: row['language'] == 'cu'
                              ? 'Monomakh'
                              : 'OldStandard',
                        ),
                      if ((row['repeatCount'] as int? ?? 1) > 1)
                        Text('Повторить ${row['repeatCount']} раз'),
                      if (row['poklon'] is String)
                        Text(row['poklon'] as String),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
