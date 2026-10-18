import 'dart:async';

import 'package:flutter/material.dart';

import '../components/trapeza_line.dart';
import '../store/reading_progress.dart';
import '../store/rule_marks.dart';
import 'posledovanie_page.dart';

/// Молебные каноны подготовки, в том порядке, в каком их читают по вечерам:
/// покаянный, Богородице, Ангелу хранителю — и сначала круга.
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

/// Подготовка к Причащению: день выбран — и вечера от сегодня до него
/// расставлены.
///
/// **Каждый вечер — канон по кругу и молитвы ко Причащению целиком.** Раскладки
/// «по частям» не выдумываем: последование ко Причащению — келейное чтение,
/// и читают его целиком, накануне и в сам день до Литургии. Поэтому вечера идут
/// включительно: последний вечер — это и утро дня причащения, до службы.
///
/// **День причащения** несёт благодарственные молитвы — читаются после
/// Причащения, — и строку трапезы этого дня: пост дня Х уходит вместе с
/// подготовкой.
///
/// Отметки «прочитано» живут обычными ключами `communion_done:<дата>:<пункт>`,
/// а доля закрытого — в общем прогрессе чтения под именем «Причастие: <дата>».
class CommunionPage extends StatefulWidget {
  /// «Сегодня». Подменяется тестами; в приложении — настоящее утро.
  final DateTime? today;

  /// Выбранный день сразу, минус диалог. Подменяется тестами; в приложении
  /// день выбирают диалогом — не раньше сегодня и не дальше сорока дней.
  final DateTime? initialDate;

  /// Строка трапезы. Подменяется тестами; в приложении — `TrapezaLine`.
  final Widget Function(DateTime date)? trapeza;

  const CommunionPage(
    context, {
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
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final results = await Future.wait<Object>(<Future<Object>>[
      ruleGender(),
      marksWithPrefix("communion_done:${dayKey(_chosen)}:"),
    ]);
    if (!mounted) return;
    setState(() {
      _gender = results[0] as String;
      _marks = results[1] as Map<String, bool>;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _chosen,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: communionHorizonDays)),
      locale: const Locale("ru"),
    );
    if (picked == null || !mounted) return;
    setState(() => _chosen = _dateOnly(picked));
    unawaited(_loadPrefs());
  }

  /// Раскладка целиком: вечера от сегодня до дня причащения включительно,
  /// затем сам день. Тот же порядок собирает прогресс — один источник.
  List<CommunionItem> _items() {
    final items = <CommunionItem>[];
    final evenings = _chosen.difference(_today).inDays;
    for (var i = 0; i <= evenings; i++) {
      final canon = communionCanons[i % communionCanons.length];
      items.add(CommunionItem(
        id: "evening$i:canon",
        title: "Канон молебный",
        subtitle: canon.$2,
        route: "/canons",
        arguments: canon.$1,
      ));
      items.add(CommunionItem(
        id: "evening$i:posledovanie",
        title: koPrichashcheniyuTitle,
        subtitle: _gender == "f" ? "в женском роде" : null,
        route: "/posledovanie",
        arguments: posledovanieRouteArgument(
          koPrichashcheniyuKey,
          koPrichashcheniyuTitle,
          gender: _gender,
        ),
      ));
    }
    items.add(CommunionItem(
      id: "day:blagodarstvennye",
      title: blagodarstvennyeTitle,
      subtitle: "после Святого Причащения",
      route: "/posledovanie",
      arguments: posledovanieRouteArgument(
        blagodarstvennyeKey,
        blagodarstvennyeTitle,
        gender: _gender,
      ),
    ));
    return items;
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
    if (!mounted) return;
    setState(() => _marks = <String, bool>{..._marks, item.id: done});
    final total = _currentItems.length;
    final doneCount =
        _currentItems.where((i) => _marks[i.id] == true).length;
    // 1.0 — край: стор сам стирает запись. Так и надо: подготовка закрыта
    // галочками, а не дочитана наполовину.
    unawaited(saveReadingProgress(
      "communion:$date",
      total == 0 ? 0 : doneCount / total,
      name: "Причастие: ${dayLabel(_chosen)}",
    ));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    _currentItems = items;
    final doneCount = items.where((i) => _marks[i.id] == true).length;

    final groups = <Widget>[
      _DateTile(date: _chosen, onTap: _pickDate),
    ];
    final evenings = _chosen.difference(_today).inDays;
    for (var i = 0; i <= evenings; i++) {
      final date = _today.add(Duration(days: i));
      groups.add(_GroupHeader(
        i == 0 ? "Сегодня вечером" : "Вечер · ${dayLabel(date)}",
      ));
      final canonItem = items[i * 2];
      final posledovanieItem = items[i * 2 + 1];
      groups.add(_itemTile(canonItem));
      groups.add(_itemTile(posledovanieItem));
    }
    groups.add(_GroupHeader("Причащение · ${dayLabel(_chosen)}"));
    groups.add(_itemTile(items.last));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Причастие", style: TextStyle(fontFamily: "OldStandard")),
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
          ...groups,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: (widget.trapeza ?? (date) => TrapezaLine(date: date))(_chosen),
          ),
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
