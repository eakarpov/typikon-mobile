import 'package:typikon/components/api_error_view.dart';
import 'package:typikon/apiMapper/session.dart';
import 'package:flutter/material.dart';
import 'package:typikon/apiMapper/reading_plan.dart';
import 'package:typikon/dto/reading_plan.dart';
import 'package:typikon/components/fusion_text.dart';
import 'package:typikon/components/reading_markdown.dart';
import 'package:typikon/utils/reading_style.dart';
import 'package:typikon/utils/reading_plan_notifications.dart';
import 'package:typikon/utils/push.dart';
import 'package:typikon/store/store.dart';

class ReadingPlanPage extends StatefulWidget {
  final String? expectedPlanId;
  const ReadingPlanPage({super.key, this.expectedPlanId});
  @override
  State<ReadingPlanPage> createState() => _ReadingPlanPageState();
}

class _ReadingPlanPageState extends State<ReadingPlanPage>
    with WidgetsBindingObserver {
  PersonalReadingPlan? _plan;
  bool _loading = true, _busy = false, _enabled = false;
  String? _error;
  String _time = '08:00';
  List<int> _days = [1, 2, 3, 4, 5, 6, 7];
  final _zone = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zone.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _load();
  }

  Future<void> _load() async {
    try {
      final p = await getReadingPlan();
      final z = p?.reminder?.timeZone ?? await deviceTimeZone();
      if (!mounted) return;
      if (widget.expectedPlanId != null && p?.id != widget.expectedPlanId)
        throw Exception(
          'Этот план больше не доступен. Откройте текущий план из настроек.',
        );
      if (appStore?.state.auth.userId != p?.userId && p != null)
        throw Exception('Вход изменился. Откройте план заново.');
      setState(() {
        _plan = p;
        _enabled = p?.reminder?.enabled ?? false;
        _time = p?.reminder?.time ?? '08:00';
        _days = [...?p?.reminder?.weekdays];
        if (p?.reminder == null) _days = [1, 2, 3, 4, 5, 6, 7];
        _zone.text = z;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e is SessionExpiredException
              ? 'Войдите в учётную запись, чтобы открыть личный план.'
              : failureMessage(
                  e,
                  'Не удалось загрузить или сохранить личный план.',
                );
          _plan = null;
        });
    }
  }

  Future<void> _act(String action, {bool settings = false}) async {
    final p = _plan;
    if (p == null) return;
    setState(() => _busy = true);
    try {
      await updateReadingPlan(
        p,
        action,
        reminder: settings
            ? PlanReminderSettings(
                enabled: _enabled,
                time: _time,
                weekdays: _days,
                timeZone: _zone.text.trim(),
              )
            : null,
      );
      await _load();
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is SessionExpiredException
              ? 'Войдите в учётную запись, чтобы открыть личный план.'
              : failureMessage(
                  e,
                  'Не удалось загрузить или сохранить личный план.',
                ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final p = _plan;
    if (p == null) return;
    setState(() => _busy = true);
    try {
      if (!await enablePush())
        throw Exception(
          'Не удалось подключить уведомления. Проверьте разрешение в настройках телефона.',
        );
      await setReadingPlanPushWanted(p.userId, true);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Этот телефон подключён к напоминаниям плана.'),
          ),
        );
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is SessionExpiredException
              ? 'Войдите в учётную запись, чтобы открыть личный план.'
              : failureMessage(
                  e,
                  'Не удалось загрузить или сохранить личный план.',
                ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Личный план чтения')),
      backgroundColor: readingBackgroundColor(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) Text(_error!),
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Обновить план'),
                  ),
                  if (p == null && _error == null)
                    const Text(
                      'План пока не создан. Создайте личный план на сайте в той же учётной записи.',
                    ),
                  if (p != null) ...[
                    Text(
                      p.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (p.status == 'paused')
                      const Text(
                        'План на паузе. Напоминания не отправляются; после возобновления действует сохранённое расписание.',
                      ),
                    if (p.status == 'completed') const Text('План завершён.'),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (p.status == 'active')
                          TextButton(
                            onPressed: _busy ? null : () => _act('pause'),
                            child: const Text('Приостановить план'),
                          ),
                        if (p.status == 'paused')
                          TextButton(
                            onPressed: _busy ? null : () => _act('resume'),
                            child: const Text('Возобновить план'),
                          ),
                      ],
                    ),
                    const Divider(),
                    const Text(
                      'Напоминания в приложении',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Напоминать об очередном чтении'),
                      value: _enabled,
                      onChanged: _busy || p.status == 'completed'
                          ? null
                          : (v) => setState(() => _enabled = v),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Время: $_time'),
                      trailing: const Icon(Icons.schedule),
                      onTap: _busy
                          ? null
                          : () async {
                              final parts = _time.split(':');
                              final t = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: int.parse(parts[0]),
                                  minute: int.parse(parts[1]),
                                ),
                              );
                              if (t != null && mounted)
                                setState(
                                  () => _time =
                                      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                                );
                            },
                    ),
                    Wrap(
                      spacing: 6,
                      children: List.generate(
                        7,
                        (i) => FilterChip(
                          label: Text(
                            const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][i],
                          ),
                          selected: _days.contains(i + 1),
                          onSelected: _busy
                              ? null
                              : (yes) => setState(
                                  () => yes
                                      ? _days.add(i + 1)
                                      : _days.remove(i + 1),
                                ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _zone,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Часовой пояс',
                        hintText: 'Europe/Moscow',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final z = await deviceTimeZone();
                              if (mounted) setState(() => _zone.text = z);
                            },
                      child: const Text('Использовать часовой пояс телефона'),
                    ),
                    FilledButton(
                      onPressed: _busy || _enabled && _days.isEmpty
                          ? null
                          : () => _act('reminder', settings: true),
                      child: const Text('Сохранить напоминания'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _connect,
                      child: const Text(
                        'Подключить этот телефон к уведомлениям',
                      ),
                    ),
                    const Text(
                      'Выбранное время считается в указанном поясе. Пропуски не накапливаются. Для получения push нужны сеть и разрешение уведомлений.',
                    ),
                    const Divider(),
                    if (p.current != null) ...[
                      Text(
                        p.current!.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (p.current!.content != null)
                        if (p.current!.markdown)
                          ReadingMarkdown(
                            p.current!.content!,
                            scrollable: false,
                          )
                        else
                          FusionTextWidgets(
                            text: p.current!.content!,
                            footnotes: p.current!.footnotes,
                            fontFamily: p.current!.csSource
                                ? 'Monomakh'
                                : 'OldStandard',
                          ),
                    ],
                    if (p.status == 'active')
                      FilledButton(
                        onPressed: _busy ? null : () => _act('advance'),
                        child: Text(
                          p.current == null
                              ? 'Перейти к следующему дню'
                              : 'Прочитано — следующее чтение',
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
