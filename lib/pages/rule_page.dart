import 'dart:async';

import 'package:flutter/material.dart';

import '../apiMapper/calendar.dart';
import '../apiMapper/singing.dart';
import '../components/async_view.dart';
import '../dto/calendar.dart' show CalendarDay, CalendarDayPartItem;
import '../dto/corpus.dart';
import '../store/reading_progress.dart';
import '../store/rule_marks.dart';
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
  /// Канон утрени. `null` — в корпусе на этот день его не нашлось: секция
  /// честно покажет плашку и кнопку ручного выбора.
  final Canon? morningCanon;

  /// Канон вечерни (повечерия). `null` — секция прячется вовсе: молебных
  /// канонов на сон в Октоихе может не быть, и пустая секция обещала бы то,
  /// чего книга не даёт.
  final Canon? eveningCanon;

  /// Дневное зачало Евангелия. `null` — секция прячется.
  final CalendarDayPartItem? gospel;

  const RuleDayData({this.morningCanon, this.eveningCanon, this.gospel});
}

/// Загрузчик канонов — чтобы правило можно было собрать в тесте без сети.
typedef CanonsLoader = Future<FacetedPage<Canon, CanonFacets>> Function({
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
Future<RuleDayData> loadRuleDay({
  DateTime? now,
  CanonsLoader canons = getCanons,
  Future<CalendarDay> Function(String date)? dayLoader,
}) async {
  final at = now ?? DateTime.now();
  final sunday = at.weekday == DateTime.sunday;

  final morningFuture = canons(
    book: "octoechos",
    service: "matins",
    role: sunday ? "voskresny" : "weekday",
  ).then<Canon?>((page) {
    for (final canon in page.items) {
      // Воскресные каноны идут по гласам, а не по дням седмицы — берём
      // первый; будничные выбираем по полю weekday.
      if (sunday || canon.weekday == canonWeekdayCode(at.weekday)) return canon;
    }
    return null;
    // Сеть молчит — честнее плашка «не найден» с ручным выбором, чем
    // упавший экран: ручной выбор работает и без сети не хуже.
  }).catchError((Object _) => null);

  final eveningFuture = canons(book: "octoechos", service: "compline")
      .then<Canon?>((page) => page.items.isEmpty ? null : page.items.first)
      .catchError((Object _) => null);

  CalendarDayPartItem? gospel;
  try {
    final day = await (dayLoader ?? getCalendarDay)(dayKey(at));
    final items = day.gospelLiturgy?.items;
    if (items != null) {
      for (final item in items) {
        if (item.isPericope &&
            (item.bookSlug ?? "").isNotEmpty &&
            item.ranges.isNotEmpty) {
          gospel = item;
          break;
        }
      }
    }
  } catch (_) {
    // Дня нет — секции Евангелия не будет. См. выше: не всякое молчание
    // сервера — повод молчать приложению.
  }

  return RuleDayData(
    morningCanon: await morningFuture,
    eveningCanon: await eveningFuture,
    gospel: gospel,
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
  final bool missing;

  const _Section({
    required this.id,
    required this.title,
    this.subtitle,
    this.evening = false,
    this.route,
    this.arguments,
    this.missing = false,
  });
}

/// Молитвенное правило дня: утро и вечер одним списком.
///
/// Состав подбирается сам: утренние молитвы — текстом корпуса, канон — из
/// Октоиха по дню седмицы, Евангелие — дневным зачалом, вечером — молитвы на
/// сон грядущим из последования и найдётся — канон вечерний. У каждой секции
/// галочка «прочитано»: день закрывается пометками, а доля закрытого идёт в
/// общий прогресс чтения под именем «Молитвенное правило».
class RulePage extends StatefulWidget {
  /// Подменяется тестами; в приложении — `loadRuleDay`.
  final Future<RuleDayData> Function()? loader;

  const RulePage(context, {super.key, this.loader});

  @override
  State<RulePage> createState() => _RulePageState();
}

class _RulePageState extends State<RulePage> {
  final DateTime _now = DateTime.now();
  late Future<RuleDayData> _data;

  String _gender = "m";
  bool _remindMorning = false;
  bool _remindEvening = false;

  /// Отметки «прочитано» по id секции.
  Map<String, bool> _marks = const <String, bool>{};

  /// Секции последнего построения: тоглу прогресса нужен их состав, и просить
  /// его заново у `FutureBuilder` неоткуда.
  List<_Section> _currentSections = const <_Section>[];

  @override
  void initState() {
    super.initState();
    _load();
    _loadPrefs();
  }

  void _load() {
    _data = widget.loader?.call() ?? loadRuleDay(now: _now);
  }

  Future<void> _refresh() {
    setState(_load);
    return settle(_data);
  }

  Future<void> _loadPrefs() async {
    final results = await Future.wait<Object>(<Future<Object>>[
      ruleGender(),
      ruleReminderEnabled(ruleRemindMorningKey),
      ruleReminderEnabled(ruleRemindEveningKey),
      marksWithPrefix("rule_done:${dayKey(_now)}:"),
    ]);
    if (!mounted) return;
    setState(() {
      _gender = results[0] as String;
      _remindMorning = results[1] as bool;
      _remindEvening = results[2] as bool;
      _marks = results[3] as Map<String, bool>;
    });
  }

  Future<void> _setReminder(String key, bool value) async {
    if (value && !await ensureNotificationPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Разрешите уведомления в настройках системы.'),
      ));
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

  List<_Section> _buildSections(RuleDayData data) {
    final gospel = data.gospel;
    return <_Section>[
      const _Section(
        id: "morning_prayers",
        title: "Молитвы утренние",
        subtitle: "из Последования дневного",
        route: "/reading",
        arguments: morningPrayersTextId,
      ),
      if (data.morningCanon != null)
        _Section(
          id: "morning_canon",
          title: "Канон утренний",
          subtitle: ruleCanonSubtitle(data.morningCanon!),
          route: "/canons",
          arguments: data.morningCanon!.id,
        )
      else
        const _Section(
          id: "morning_canon",
          title: "Канон утренний",
          missing: true,
        ),
      if (gospel != null)
        _Section(
          id: "gospel",
          title: "Глава Евангелия дня",
          subtitle: gospel.name,
          route: "/bible",
          arguments: bibleRouteArgument(
            gospel.bookSlug!,
            chapter: gospel.ranges.first.chapterFrom,
            ranges: gospel.ranges,
          ),
        ),
      _Section(
        id: "evening_prayers",
        title: "Молитвы на сон грядущим",
        subtitle: _gender == "f" ? "в женском роде" : null,
        evening: true,
        route: "/posledovanie",
        arguments: posledovanieRouteArgument(
          "na-son",
          "Молитвы на сон грядущим",
          gender: _gender,
        ),
      ),
      if (data.eveningCanon != null)
        _Section(
          id: "evening_canon",
          title: "Канон вечерний",
          subtitle: ruleCanonSubtitle(data.eveningCanon!),
          evening: true,
          route: "/canons",
          arguments: data.eveningCanon!.id,
        ),
    ];
  }

  Future<void> _toggle(_Section section, bool done) async {
    final date = dayKey(_now);
    await setRuleSectionDone(date, section.id, done);
    if (!mounted) return;
    setState(() => _marks = <String, bool>{..._marks, section.id: done});
    final total = _currentSections.length;
    final doneCount =
        _currentSections.where((s) => _marks[s.id] == true).length;
    // 1.0 — край: стор сам стирает запись, и имя в «продолжить чтение» не
    // горит. Так и надо: день закрыт галочками, а не дочитан наполовину.
    unawaited(saveReadingProgress(
      "rule:$date",
      total == 0 ? 0 : doneCount / total,
      name: "Молитвенное правило",
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Правило дня", style: TextStyle(fontFamily: "OldStandard")),
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
        const _GroupHeader("Утро"),
        for (final section in sections.where((s) => !s.evening))
          _sectionTile(section),
        const _GroupHeader("Вечер"),
        for (final section in sections.where((s) => s.evening))
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

    if (section.missing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListTile(
            leading: Checkbox(
              value: done,
              onChanged: (value) => unawaited(_toggle(section, value ?? false)),
            ),
            title: Text(section.title),
            subtitle: const Text("Канон не найден: Октоих на этот день "
                "в корпусе молчит."),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text("выбрать вручную"),
              // Предустановленный отбор у перечня канонов не предусмотрен —
              // открываем его как есть: книга и служба подписаны у каждого.
              onPressed: () => Navigator.pushNamed(context, "/canons"),
            ),
          ),
        ],
      );
    }

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
