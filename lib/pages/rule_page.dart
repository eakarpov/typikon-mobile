import 'dart:async';

import 'package:flutter/material.dart';

import '../apiMapper/calendar.dart';
import '../apiMapper/singing.dart';
import '../apiMapper/ordo.dart';
import 'rule_office_page.dart';
import '../components/async_view.dart';
import '../dto/calendar.dart' show CalendarDay, CalendarDayPartItem;
import '../dto/corpus.dart';
import '../store/reading_progress.dart';
import '../store/rule_marks.dart';
import '../store/rule_cycle.dart';
import '../utils/route_observer.dart';
import '../utils/bible_route.dart';
import '../utils/rule_reminders.dart';
import '../utils/notification_permission.dart';
import '../utils/singing_labels.dart';
import 'posledovanie_page.dart';

/// «Утренние молитвы» текущего корпуса: правило дня открывает их обычным
/// `/reading`, как любой текст собрания.
const String morningPrayersTextId = "67e0472294428ce850c0f9bd";

/// Что автоподбор собрал для правила сегодняшнего дня.
class RuleDayData {
  /// Канон Троице воскресной полунощницы. В будни канона нет.
  final Canon? morningCanon;

  /// Канон повечерия для дня недели и гласа.
  final Canon? eveningCanon;
  final int? tone;
  final int? eveningTone;

  /// Дневное зачало Евангелия. `null` — секция прячется.
  final CalendarDayPartItem? gospel;

  const RuleDayData({
    this.morningCanon,
    this.eveningCanon,
    this.gospel,
    int? tone,
    int? morningTone,
    int? eveningTone,
  }) : tone = morningTone ?? tone,
       eveningTone = eveningTone ?? tone;
}

/// Загрузчик канонов — чтобы правило можно было собрать в тесте без сети.
typedef CanonsLoader =
    Future<FacetedPage<Canon, CanonFacets>> Function({
      String? query,
      int offset,
      String? book,
      int? tone,
      String? service,
      String? role,
    });

/// Код дня седмицы, как его пишет певческий корпус: `DateTime.weekday`
/// (понедельник — 1) → «ponedelnik»…«voskresenie».
String canonWeekdayCode(int weekday) => const <String>[
  "ponedelnik",
  "vtornik",
  "sreda",
  "chetverg",
  "pyatnica",
  "subbota",
  "voskresenie",
][weekday - 1];

/// Подпись канона для строки правила: «Память · глас 4, вторник · глас 1».
String ruleCanonSubtitle(Canon canon) => <String>[
  if (canon.memory.isNotEmpty) canon.memory,
  memoryAddress(
    book: canon.book,
    month: canon.month,
    day: canon.day,
    paschaOffset: canon.paschaOffset,
    weekday: canon.weekday,
    memoryTone: canon.memoryTone,
  ),
  if (canon.tone != null) "глас ${canon.tone}",
].where((part) => part.isNotEmpty).join(" · ");

/// Автоподбор правила дня: каноны Октоиха по дню седмицы и зачало Евангелия
/// из дня.
///
/// Отказы частей гасим частями: не вышло достать каноны — секция покажет
/// плашку, не вышло достать день — Евангелия в правиле просто не будет.
/// Ронять весь экран из-за одной секции незачем: молитвы утренние и на сон
/// не от сервера зависят вовсе.
const String midnightDailyTextId = '67dbc9c427c94f2d975da68a';
const String midnightSaturdayTextId = '67dbdbb0593e26758a828d09';
const String midnightSundayTextId = '67dbdcd6593e26758a828d0b';
const String complineTextId = '67df2a9b94428ce850c0f9af';

String midnightTextId(int weekday) => weekday == DateTime.sunday
    ? midnightSundayTextId
    : weekday == DateTime.saturday
    ? midnightSaturdayTextId
    : midnightDailyTextId;
String midnightTitle(int weekday) => weekday == DateTime.sunday
    ? 'Полунощница воскресная'
    : weekday == DateTime.saturday
    ? 'Полунощница субботняя'
    : 'Полунощница вседневная';

Future<RuleDayData> loadRuleDay({
  DateTime? now,
  DateTime? eveningDate,
  CanonsLoader canons = getCanons,
  Future<CalendarDay> Function(String date)? dayLoader,
  Future<int?> Function(DateTime date)? toneLoader,
  bool morningOffice = false,
  bool eveningOffice = false,
}) async {
  final at = now ?? DateTime.now();
  final needsMorningCanon = morningOffice && at.weekday == DateTime.sunday;
  final eveningAt = eveningDate ?? at;
  Future<int?> readTone(DateTime date) async {
    try {
      return await (toneLoader ?? getOrdoTone)(date);
    } catch (_) {
      return null;
    }
  }

  final morningTone = needsMorningCanon ? await readTone(at) : null;
  final eveningTone = eveningOffice
      ? (dayKey(eveningAt) == dayKey(at) && needsMorningCanon
            ? morningTone
            : await readTone(eveningAt))
      : null;
  Future<Canon?> choose(String service, DateTime date, int? tone) async {
    if (tone == null) return null;
    var offset = 0;
    while (true) {
      final page = await canons(
        book: 'octoechos',
        service: service,
        offset: offset,
      );
      for (final canon in page.items) {
        if ((canon.language == null ||
                canon.language == 'cu' ||
                canon.language == 'cu_gr') &&
            canon.weekday == canonWeekdayCode(date.weekday) &&
            (canon.memoryTone ?? canon.tone) == tone) {
          return canon;
        }
      }
      offset += page.limit > 0 ? page.limit : 25;
      if (page.items.isEmpty || offset >= page.total) return null;
    }
  }

  final morning = needsMorningCanon
      ? choose('midnight', at, morningTone).catchError((Object _) => null)
      : Future<Canon?>.value();
  final evening = eveningOffice
      ? choose(
          'compline',
          eveningAt,
          eveningTone,
        ).catchError((Object _) => null)
      : Future<Canon?>.value();
  CalendarDayPartItem? gospel;
  try {
    final day = await (dayLoader ?? getCalendarDay)(dayKey(at));
    for (final item in day.gospelLiturgy?.items ?? <CalendarDayPartItem>[]) {
      if (item.isPericope &&
          (item.bookSlug ?? '').isNotEmpty &&
          item.ranges.isNotEmpty) {
        gospel = item;
        break;
      }
    }
  } catch (_) {
    /* Молитвы читаются независимо от календарного зачала. */
  }
  return RuleDayData(
    morningCanon: await morning,
    eveningCanon: await evening,
    gospel: gospel,
    morningTone: morningTone,
    eveningTone: eveningTone,
  );
}

/// Один раздел дня: что читается и куда это открывается.
class _Section {
  final String id;
  final String title;
  final String? subtitle;

  /// Утро или вечер: разбиение на группы — часть данных, а не угадайка по id.
  final bool evening;

  /// Куда вести тап по строке. `null` — у секции нет открытия (плашка).
  final String? route;
  final Object? arguments;

  /// Канон не подобрался: вместо перехода — честная плашка с кнопкой.

  const _Section({
    required this.id,
    required this.title,
    this.subtitle,
    this.evening = false,
    this.route,
    this.arguments,
  });
}

/// Молитвенное правило дня: утро и вечер одним списком.
///
/// Утро и вечер независимо выбираются из Молитвослова или Часослова.
/// Каноны относятся к службам Часослова: к воскресной полунощнице и повечерию. У каждой секции
/// галочка «прочитано»: день закрывается пометками, а доля закрытого идёт в
/// общий прогресс чтения под именем «Молитвенное правило».
class RulePage extends StatefulWidget {
  /// Подменяется тестами; в приложении — `loadRuleDay`.
  final Future<RuleDayData> Function()? loader;
  final DateTime? date;
  final DateTime Function()? now;

  const RulePage(
    BuildContext? context, {
    super.key,
    this.loader,
    this.date,
    this.now,
  });

  @override
  State<RulePage> createState() => _RulePageState();
}

class _RulePageState extends State<RulePage>
    with WidgetsBindingObserver, RouteAware {
  late RuleCycle _cycle;
  Timer? _resetTimer;
  PageRoute<dynamic>? _route;
  DateTime get _now => _cycle.morning;
  DateTime _clock() => widget.now?.call() ?? widget.date ?? DateTime.now();

  void _scheduleReset() {
    _resetTimer?.cancel();
    final now = _clock();
    _resetTimer = Timer(
      RuleCycle.at(now).nextReset.difference(now),
      _syncCycle,
    );
  }

  void _syncCycle({bool reloadPrefs = true}) {
    if (!mounted) return;
    final next = RuleCycle.at(_clock());
    final changed = next.key != _cycle.key;
    if (changed) {
      setState(() {
        _cycle = next;
        _marks = {};
        _currentSections = [];
        _load();
      });
    }
    if (changed || reloadPrefs) unawaited(_loadPrefs());
    _scheduleReset();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      routeObserver.unsubscribe(this);
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() => _syncCycle();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncCycle();
    } else {
      _resetTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _morningOffice = false;
  bool _eveningOffice = false;
  late Future<RuleDayData> _data;

  String _gender = "m";
  bool _remindMorning = false;
  bool _remindEvening = false;

  /// Отметки «прочитано» по id секции.
  Map<String, bool> _marks = const <String, bool>{};
  int _marksRevision = 0;

  /// Секции последнего построения: тоглу прогресса нужен их состав, и просить
  /// его заново у `FutureBuilder` неоткуда.
  List<_Section> _currentSections = const <_Section>[];

  @override
  void initState() {
    super.initState();
    _cycle = RuleCycle.at(_clock());
    WidgetsBinding.instance.addObserver(this);
    _scheduleReset();
    _load();
    _loadPrefs();
  }

  void _load() {
    _data =
        widget.loader?.call() ??
        loadRuleDay(
          now: _now,
          eveningDate: _cycle.evening,
          morningOffice: _morningOffice,
          eveningOffice: _eveningOffice,
        );
  }

  Future<void> _refresh() {
    _syncCycle();
    setState(_load);
    return settle(_data);
  }

  Future<void> _loadPrefs() async {
    final cycle = _cycle;
    final marksRevision = _marksRevision;
    final results = await Future.wait<Object>(<Future<Object>>[
      ruleGender(),
      ruleReminderEnabled(ruleRemindMorningKey),
      ruleReminderEnabled(ruleRemindEveningKey),
      ruleCycleMarks(cycle),
      ruleUsesHorologion(true),
      ruleUsesHorologion(false),
    ]);
    if (!mounted || cycle.key != _cycle.key) return;
    setState(() {
      _gender = results[0] as String;
      _remindMorning = results[1] as bool;
      _remindEvening = results[2] as bool;
      if (marksRevision == _marksRevision) {
        _marks = results[3] as Map<String, bool>;
      }
      _morningOffice = results[4] as bool;
      _eveningOffice = results[5] as bool;
      if (widget.loader == null && (_morningOffice || _eveningOffice)) _load();
    });
  }

  Future<void> _setReminder(String key, bool value) async {
    if (value && !await ensureNotificationPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Разрешите уведомления в настройках системы.'),
        ),
      );
      return;
    }
    await setRuleReminder(key, value);
    if (!mounted) return;
    setState(() {
      if (key == ruleRemindMorningKey) {
        _remindMorning = value;
      } else {
        _remindEvening = value;
      }
    });
  }

  void _setGender(String gender) {
    setState(() => _gender = gender);
    unawaited(setRuleGender(gender));
  }

  Widget _sourceChoice(bool morning) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: SegmentedButton<bool>(
      key: ValueKey(morning ? 'morning_source' : 'evening_source'),
      segments: const [
        ButtonSegment(value: false, label: Text('Молитвослов')),
        ButtonSegment(value: true, label: Text('Часослов')),
      ],
      selected: {morning ? _morningOffice : _eveningOffice},
      onSelectionChanged: (values) {
        final value = values.first;
        unawaited(setRuleHorologion(morning, value));
        setState(() {
          if (morning) {
            _morningOffice = value;
          } else {
            _eveningOffice = value;
          }
          _load();
        });
      },
    ),
  );

  List<_Section> _buildSections(RuleDayData data) {
    final gospel = data.gospel;
    return [
      if (!_morningOffice)
        _Section(
          id: 'morning_prayerbook',
          title: 'Молитвы утренние',
          subtitle: 'Молитвослов',
          route: '/posledovanie',
          arguments: posledovanieRouteArgument(
            'utrennie',
            'Молитвы утренние',
            gender: _gender,
          ),
        )
      else ...[
        const _Section(
          id: 'morning_horologion',
          title: 'Утренние молитвы Часослова',
          route: '/reading',
          arguments: morningPrayersTextId,
        ),
        _Section(
          id: 'midnight',
          title: midnightTitle(_now.weekday),
          route: '/rule/office',
          subtitle: _now.weekday == DateTime.sunday
              ? data.tone == null
                    ? 'Глас не определён'
                    : 'С каноном Троице · глас ${data.tone}'
              : null,
          arguments: RuleOfficeTarget(
            textId: midnightTextId(_now.weekday),
            title: midnightTitle(_now.weekday),
            canonId: data.morningCanon?.id,
            tone: data.tone,
            needsCanon: _now.weekday == DateTime.sunday,
          ),
        ),
      ],
      if (gospel != null)
        _Section(
          id: 'gospel',
          title: 'Глава Евангелия дня',
          subtitle: gospel.name,
          route: '/bible',
          arguments: bibleRouteArgument(
            gospel.bookSlug!,
            chapter: gospel.ranges.first.chapterFrom,
            ranges: gospel.ranges,
          ),
        ),
      if (!_eveningOffice)
        _Section(
          id: 'evening_prayerbook',
          title: 'Молитвы на сон грядущим',
          subtitle: 'Молитвослов',
          evening: true,
          route: '/posledovanie',
          arguments: posledovanieRouteArgument(
            'na-son',
            'Молитвы на сон грядущим',
            gender: _gender,
          ),
        )
      else
        _Section(
          id: 'compline',
          title: 'Повечерие с каноном',
          evening: true,
          subtitle: data.eveningTone == null
              ? 'Глас не определён'
              : 'Глас ${data.eveningTone}',
          route: '/rule/office',
          arguments: RuleOfficeTarget(
            textId: complineTextId,
            title: 'Повечерие с каноном',
            canonId: data.eveningCanon?.id,
            tone: data.eveningTone,
            needsCanon: true,
          ),
        ),
    ];
  }

  Future<void> _toggle(_Section section, bool done) async {
    final cycle = _cycle;
    _syncCycle(reloadPrefs: false);
    if (cycle.key != _cycle.key) return;
    _marksRevision++;
    await setRuleCycleSectionDone(cycle, section.id, done);
    if (!mounted || cycle.key != _cycle.key) return;
    setState(() => _marks = <String, bool>{..._marks, section.id: done});
    final total = _currentSections.length;
    final doneCount = _currentSections
        .where((s) => _marks[s.id] == true)
        .length;
    // 1.0 — край: стор сам стирает запись, и имя в «продолжить чтение» не
    // горит. Так и надо: день закрыт галочками, а не дочитан наполовину.
    unawaited(
      doneCount == 0
          ? clearReadingProgress(cycle.progressId)
          : saveReadingProgress(
              cycle.progressId,
              total == 0 ? 0 : doneCount / total,
              name: "Молитвенное правило",
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Правило дня",
          style: TextStyle(fontFamily: "OldStandard"),
        ),
        actions: <Widget>[
          // Род молящегося меняет текст последований (молитвы спрашивают
          // «раб Твой» или «раба Твоя») — решает хозяин устройства, и его
          // выбор запоминается.
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: "m", label: Text("м")),
                ButtonSegment<String>(value: "f", label: Text("ж")),
              ],
              selected: <String>{_gender},
              onSelectionChanged: (selection) => _setGender(selection.first),
            ),
          ),
        ],
      ),
      body: AsyncView<RuleDayData>(
        future: _data,
        message: "Не удалось открыть правило дня.",
        onRetry: () => setState(_load),
        onRefresh: _refresh,
        builder: (context, data) {
          final sections = _buildSections(data);
          _currentSections = sections;
          return _body(sections);
        },
      ),
    );
  }

  Widget _body(List<_Section> sections) {
    final doneCount = sections.where((s) => _marks[s.id] == true).length;

    return ListView(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LinearProgressIndicator(
                value: sections.isEmpty ? 0 : doneCount / sections.length,
              ),
              const SizedBox(height: 4.0),
              Text("прочитано разделов: $doneCount/${sections.length}"),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Вечер ${dayLabel(_cycle.evening)} — утро ${dayLabel(_cycle.morning)}. '
            'Новое правило каждый день в 15:00.',
          ),
        ),
        const _GroupHeader("Вечер"),
        _sourceChoice(false),
        for (final section in sections.where((s) => s.evening))
          _sectionTile(section),
        const _GroupHeader("Утро"),
        _sourceChoice(true),
        for (final section in sections.where((s) => !s.evening))
          _sectionTile(section),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text("Напоминать утром"),
          subtitle: const Text("в 7:00 — «Время молитвенного правила»"),
          value: _remindMorning,
          onChanged: (value) => _setReminder(ruleRemindMorningKey, value),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text("Напоминать вечером"),
          subtitle: const Text("в 21:00 — «Время молитвенного правила»"),
          value: _remindEvening,
          onChanged: (value) => _setReminder(ruleRemindEveningKey, value),
        ),
      ],
    );
  }

  Widget _sectionTile(_Section section) {
    final done = _marks[section.id] == true;

    return ListTile(
      leading: Checkbox(
        value: done,
        onChanged: (value) => unawaited(_toggle(section, value ?? false)),
      ),
      title: Text(section.title),
      subtitle: section.subtitle == null ? null : Text(section.subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: section.route == null
          ? null
          : () => Navigator.pushNamed(
              context,
              section.route!,
              arguments: section.arguments,
            ),
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
