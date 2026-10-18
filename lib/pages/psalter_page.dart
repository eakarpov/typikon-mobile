import 'package:flutter/material.dart';

import 'package:typikon/apiMapper/ordo.dart';
import 'package:typikon/domain/psalter.dart';
import 'package:typikon/dto/ordo.dart';
import 'package:typikon/pages/kathisma_page.dart' show kathismaRouteArgument;
import 'package:typikon/pages/psalter_serial_page.dart' show serialRouteArgument;
import 'package:typikon/store/psalter_mode.dart';
import 'package:typikon/store/reading_progress.dart';

/// Псалтирь: двадцать кафизм, дополнительный псалом 151 и вход в непрерывное
/// чтение («подряд»).
///
/// У кафизмы в списке три отметки: номер-имя, прогресс чтения по статьям
/// (доля скролла → трети, см. `domain/psalter.dart`) и пометка «сегодня» —
/// по каким службам кафизма читается по уставу сегодня. Пометка живёт от
/// сервера (`/api/v2/ordo/day`): пока ответа нет, кафизмы просто без неё —
/// это прибавка, а не условие чтения.
///
/// Раздел «О усопших» — три входа в поминальное чтение: переключатель
/// «имена усопших на славах» (кафизмы и «Подряд» открываются с молитвами),
/// сорокоуст по дате преставления и Неусыпаемая Псалтирь («Подряд» с
/// поминовением). Молитвы с именами — прибавка к чтению, и без входа или
/// сети кафизма читается как обычная.
class PsalterPage extends StatefulWidget {
  /// Подменяется тестами; в приложении — запрос к ordo.
  final Future<OrdoKafizmy?> Function()? todayLoader;

  const PsalterPage({super.key, this.todayLoader});

  @override
  State<PsalterPage> createState() => _PsalterPageState();
}

class _PsalterPageState extends State<PsalterPage> {
  /// Прогресс кафизм по записям «продолжить чтение»: номер → доля скролла.
  Map<int, ReadingProgress> _progress = const <int, ReadingProgress>{};

  /// Кафизмы сегодняшнего уставного дня. `null` — сервер не ответил или
  /// кафизм в дне нет: не помечаем ничего.
  OrdoKafizmy? _today;

  /// «Имена усопших на славах»: поминальный режим для кафизм и «Подряд».
  bool _departedMode = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _loadToday();
    _loadDepartedMode();
  }

  Future<void> _loadDepartedMode() async {
    final on = await psalterDepartedMode();
    if (mounted) setState(() => _departedMode = on);
  }

  Future<void> _setDepartedMode(bool on) async {
    await setPsalterDepartedMode(on);
    if (mounted) setState(() => _departedMode = on);
  }

  Future<void> _loadProgress() async {
    final all = await getAllReadingProgress();
    final found = <int, ReadingProgress>{};
    for (final entry in all) {
      if (!entry.id.startsWith("psalter:kathisma:")) continue;
      final number = int.tryParse(entry.id.substring("psalter:kathisma:".length));
      if (number != null) found[number] = entry.progress;
    }
    if (mounted) setState(() => _progress = found);
  }

  Future<void> _loadToday() async {
    final kafizmy = await (widget.todayLoader ?? getTodayKafizmy)();
    if (mounted) setState(() => _today = kafizmy);
  }

  void _openKathisma(int number) {
    // Поминальный режим — строковый аргумент «N|d»; обычный — прежнее
    // голое число.
    Navigator.pushNamed(
      context,
      "/psalter/kathisma",
      arguments: _departedMode
          ? kathismaRouteArgument(number, departed: true)
          : number,
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Псалтирь", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: ListView(
        children: <Widget>[
          if (today != null && !today.isEmpty)
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text("Сегодня по уставу"),
              subtitle: Text(today.label),
            ),
          for (final number in kathismaRanges.keys)
            _kathismaTile(number, today),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text("Псалом 151 (дополнительный)"),
            subtitle: const Text("Не входит в кафизмы; семь стихов"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openKathisma(psalm151),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text("Подряд"),
            subtitle: const Text("Непрерывное чтение всей Псалтири"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(
              context,
              "/psalter/serial",
              arguments: serialRouteArgument(departed: _departedMode),
            ),
          ),
          _departedSection(context),
        ],
      ),
    );
  }

  /// Раздел «О усопших»: три входа в поминальное чтение.
  Widget _departedSection(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
          child: Text(
            "О усопших",
            style: TextStyle(
              fontFamily: "OldStandard",
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.favorite_outline),
          title: const Text("Чтение с поминовением"),
          subtitle: const Text("имена усопших на славах"),
          trailing: Switch(
            value: _departedMode,
            onChanged: _setDepartedMode,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.hourglass_empty),
          title: const Text("Сорокоуст"),
          subtitle: const Text("Кафизма дня по дате преставления"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, "/psalter/sorokoust"),
        ),
        ListTile(
          leading: const Icon(Icons.nightlight_outlined),
          title: const Text("Неусыпаемая Псалтирь"),
          subtitle: const Text("Непрерывное чтение с поминовением"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(
            context,
            "/psalter/serial",
            arguments: serialRouteArgument(departed: true),
          ),
        ),
      ],
    );
  }

  Widget _kathismaTile(int number, OrdoKafizmy? today) {
    final saved = _progress[number];
    final read = saved == null ? 0 : statiiRead(saved.fraction);
    final services = today?.servicesFor(number) ?? const <String>[];
    final isToday = services.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.chrome_reader_mode),
          title: Text(kathismaTitle(number)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (read > 0) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, bottom: 4.0),
                  child: LinearProgressIndicator(value: read / 3, minHeight: 3),
                ),
                Text("прочитано статей: $read/3"),
              ],
              if (isToday) Text("сегодня: ${services.join(", ")}"),
            ],
          ),
          trailing: isToday
              ? const Chip(label: Text("Сегодня"))
              : const Icon(Icons.chevron_right),
          onTap: () => _openKathisma(number),
        ),
      ],
    );
  }
}
