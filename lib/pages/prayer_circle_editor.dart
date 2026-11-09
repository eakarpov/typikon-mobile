import 'package:flutter/material.dart';
import '../domain/prayer_circle.dart';
import '../utils/notification_permission.dart';

const circleParts = {
  'evening': 'Вечер',
  'morning': 'Утро',
  'day': 'В течение дня',
};

class PrayerCircleEditor extends StatefulWidget {
  final CircleJson config, catalog;
  const PrayerCircleEditor({
    super.key,
    required this.config,
    required this.catalog,
  });
  @override
  State<PrayerCircleEditor> createState() => _PrayerCircleEditorState();
}

class _PrayerCircleEditorState extends State<PrayerCircleEditor> {
  late CircleJson c;
  late String selected;
  bool today = false;
  @override
  void initState() {
    super.initState();
    c = circleCopy(widget.config);
    selected = c['activeId'] as String;
  }

  List<CircleJson> get variants => circleList(c['variants']);
  CircleJson get variant => variants.firstWhere((v) => v['id'] == selected);
  List<CircleJson> get blocks => circleList(variant['blocks']);
  void updateVariant(CircleJson value) {
    setState(
      () => c['variants'] = variants
          .map((v) => v['id'] == selected ? value : v)
          .toList(),
    );
  }

  void updateBlocks(List<CircleJson> value) => updateVariant({
    ...variant,
    'basedOn': variant['basedOn'] ?? 'personal',
    'blocks': value,
  });
  void updateBlock(int i, CircleJson value) {
    final all = blocks;
    all[i] = value;
    updateBlocks(all);
  }

  Future<void> add() async {
    final choices = <CircleJson>[
      ...circleList(widget.catalog['templates'])
          .where((t) => t['status'] == 'verified')
          .map(
            (t) => {
              'kind': 'template',
              'key': t['key'],
              'title': t['title'],
              'part': t['part'],
            },
          ),
      {'kind': 'psalter', 'key': 'psaltir', 'title': 'Псалтирь'},
      {'kind': 'day-readings', 'key': 'gospel', 'title': 'Евангелие дня'},
      {
        'kind': 'day-readings',
        'key': 'all',
        'title': 'Апостол и Евангелие дня',
      },
      {'kind': 'reading-plan', 'key': 'current', 'title': 'Личный план чтения'},
      ...circleList(
        circleMap(widget.catalog['options'])['scripture'],
      ).map((o) => {...o, 'kind': 'scripture'}),
      ...circleList(
        circleMap(widget.catalog['options'])['canons'],
      ).map((o) => {...o, 'kind': 'canon'}),
      ...circleList(
        circleMap(widget.catalog['options'])['akathists'],
      ).map((o) => {...o, 'kind': 'akathist'}),
    ];
    final selected = await showModalBottomSheet<CircleJson>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: _BlockPicker(choices),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final block = <String, dynamic>{
      ...selected,
      'id': circleOperationId(),
      'part': selected['part'] ?? 'morning',
      'weekdays': [1, 2, 3, 4, 5, 6, 7],
      if (selected['kind'] == 'psalter') ...{
        'mode': 'continuous',
        'unit': 'kathisma',
        'departed': false,
      },
      if (selected['kind'] == 'scripture') 'chapter': 1,
      if (selected['key'] == 'jesus') 'count': 100,
    };
    updateBlocks([...blocks, block]);
  }

  Future<void> save() async {
    try {
      validateCircleConfig(c);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (variants.any(
      (v) =>
          (v['title'] as String).trim().isEmpty ||
          circleList(v['blocks']).any((b) => (b['weekdays'] as List).isEmpty),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Укажите название и хотя бы один день недели для каждого чтения.',
          ),
        ),
      );
      return;
    }
    final reminders = circleMap(c['reminders']);
    if ((reminders['morning'] == true || reminders['evening'] == true) &&
        !await ensureNotificationPermission()) {
      reminders['morning'] = false;
      reminders['evening'] = false;
      c['reminders'] = reminders;
    }
    if (!mounted) return;
    Navigator.pop(context, {'config': c, 'applyToday': today});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Состав и расписание'),
      actions: [
        IconButton(
          onPressed: save,
          icon: const Icon(Icons.check),
          tooltip: 'Сохранить',
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: selected,
          key: ValueKey(selected),
          decoration: const InputDecoration(labelText: 'Мои варианты'),
          items: variants
              .map(
                (v) => DropdownMenuItem(
                  value: v['id'] as String,
                  child: Text(v['title'] as String),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => selected = v!),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () {
                final id = circleOperationId();
                setState(() {
                  c['variants'] = [
                    ...variants,
                    {'id': id, 'title': 'Новое правило', 'blocks': []},
                  ];
                  selected = id;
                });
              },
              child: const Text('Пустой вариант'),
            ),
            TextButton(
              onPressed: () {
                final id = circleOperationId();
                final copy = {
                  ...variant,
                  'id': id,
                  'title': '${variant['title']} — личный',
                  'basedOn': variant['id'],
                  'blocks': blocks
                      .map((b) => {...b, 'id': circleOperationId()})
                      .toList(),
                };
                setState(() {
                  c['variants'] = [...variants, copy];
                  selected = id;
                });
              },
              child: const Text('Скопировать'),
            ),
          ],
        ),
        OutlinedButton(
          onPressed: variants.length <= 1
              ? null
              : () {
                  final remaining = variants
                      .where((v) => v['id'] != selected)
                      .toList();
                  setState(() {
                    c['variants'] = remaining;
                    if (c['activeId'] == selected)
                      c['activeId'] = remaining.first['id'];
                    selected = remaining.first['id'] as String;
                  });
                },
          child: const Text('Удалить вариант'),
        ),
        TextFormField(
          key: ValueKey('title:$selected'),
          initialValue: variant['title'] as String,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Название'),
          onChanged: (v) => updateVariant({...variant, 'title': v}),
        ),
        SwitchListTile(
          title: const Text('Использовать по умолчанию'),
          value: c['activeId'] == selected,
          onChanged: (v) {
            if (v) setState(() => c['activeId'] = selected);
          },
        ),
        for (var i = 0; i < blocks.length; i++) _block(i, blocks[i]),
        OutlinedButton.icon(
          onPressed: blocks.length >= 60 ? null : add,
          icon: const Icon(Icons.add),
          label: const Text('Добавить чтение'),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: c['gender'] as String,
          decoration: const InputDecoration(labelText: 'Род молитв'),
          items: const [
            DropdownMenuItem(value: 'm', child: Text('Мужской')),
            DropdownMenuItem(value: 'f', child: Text('Женский')),
          ],
          onChanged: (v) => setState(() => c['gender'] = v),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: c['readerFont'] as String? ?? 'civil',
          decoration: const InputDecoration(labelText: 'Шрифт читателя'),
          items: const [
            DropdownMenuItem(value: 'civil', child: Text('Гражданский')),
            DropdownMenuItem(
              value: 'church',
              child: Text('Церковнославянский'),
            ),
          ],
          onChanged: (v) => setState(() => c['readerFont'] = v),
        ),
        const Text(
          'Шрифт меняет оформление. Источник и редакция текста сохраняются.',
        ),
        SwitchListTile(
          title: const Text('Утреннее напоминание'),
          subtitle: const Text('В окне 7–9, когда разрешит система'),
          value: circleMap(c['reminders'])['morning'] == true,
          onChanged: (v) => setState(
            () => c['reminders'] = {...circleMap(c['reminders']), 'morning': v},
          ),
        ),
        SwitchListTile(
          title: const Text('Вечернее напоминание'),
          subtitle: const Text('В окне 21–23, когда разрешит система'),
          value: circleMap(c['reminders'])['evening'] == true,
          onChanged: (v) => setState(
            () => c['reminders'] = {...circleMap(c['reminders']), 'evening': v},
          ),
        ),
        ListTile(
          title: const Text('Подготовка к Причащению'),
          subtitle: Text(
            circleMap(c['communion'])['date'] as String? ?? 'Дата не выбрана',
          ),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: now,
              lastDate: now.add(const Duration(days: 40)),
            );
            if (d != null)
              setState(
                () => c['communion'] = {
                  'date': d.toIso8601String().substring(0, 10),
                  'days': circleMap(c['communion'])['days'] ?? 3,
                },
              );
          },
        ),
        if (circleMap(c['communion']).isNotEmpty) ...[
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: circleMap(c['communion'])['days'] as int? ?? 3,
            decoration: const InputDecoration(labelText: 'Дней подготовки'),
            items: List.generate(
              41,
              (n) => DropdownMenuItem(value: n, child: Text('$n')),
            ),
            onChanged: (n) => setState(
              () => c['communion'] = {...circleMap(c['communion']), 'days': n},
            ),
          ),
          TextButton(
            onPressed: () => setState(() => c.remove('communion')),
            child: const Text('Убрать подготовку из круга'),
          ),
        ],
        if (circleMap(c['communion']).isNotEmpty) ...[
          SwitchListTile(
            title: const Text('Индивидуальный состав подготовки'),
            value: circleMap(c['communion'])['customKeys'] != null,
            onChanged: (on) => setState(() {
              final plan = circleMap(c['communion']);
              if (on) {
                plan['customKeys'] = ['trekhkanonnik', 'ko-prichashcheniyu'];
              } else {
                plan.remove('customKeys');
              }
              c['communion'] = plan;
            }),
          ),
          if (circleMap(c['communion'])['customKeys'] != null)
            for (final template
                in circleList(widget.catalog['templates']).where(
                  (t) =>
                      t['status'] == 'verified' &&
                      !['horologion', 'blagodarstvennye'].contains(t['key']),
                ))
              CheckboxListTile(
                title: Text(template['title'] as String),
                value: (circleMap(c['communion'])['customKeys'] as List)
                    .contains(template['key']),
                onChanged: (on) => setState(() {
                  final plan = circleMap(c['communion']);
                  final keys = List<String>.from(plan['customKeys'] as List);
                  if (on == true) {
                    keys.add(template['key'] as String);
                  } else {
                    keys.remove(template['key']);
                  }
                  plan['customKeys'] = keys;
                  c['communion'] = plan;
                }),
              ),
        ],
        SwitchListTile(
          title: const Text('Применить сегодня'),
          subtitle: const Text(
            'Иначе новый состав начнётся со следующего цикла в 15:00',
          ),
          value: today,
          onChanged: (v) => setState(() => today = v),
        ),
        FilledButton(onPressed: save, child: const Text('Сохранить')),
      ],
    ),
  );
  Widget _block(int i, CircleJson b) => Card(
    key: ValueKey(b['id']),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            b['title'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: b['part'] as String,
            items: circleParts.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (p) => updateBlock(i, {...b, 'part': p}),
          ),
          Wrap(
            children: List.generate(
              7,
              (n) => FilterChip(
                label: Text(['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][n]),
                selected: (b['weekdays'] as List).contains(n + 1),
                onSelected: (on) {
                  final days = List<int>.from(b['weekdays'] as List);
                  if (on) {
                    days.add(n + 1);
                  } else {
                    days.remove(n + 1);
                  }
                  updateBlock(i, {...b, 'weekdays': days});
                },
              ),
            ),
          ),
          if (['canon', 'akathist'].contains(b['kind']) ||
              b['key'] == 'trekhkanonnik')
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: b['placement'] as String? ?? 'standalone',
              decoration: const InputDecoration(labelText: 'Способ чтения'),
              items: const [
                DropdownMenuItem(
                  value: 'standalone',
                  child: Text('Самостоятельно'),
                ),
                DropdownMenuItem(
                  value: 'embedded',
                  child: Text('Внутри Молитвословного правила'),
                ),
              ],
              onChanged: (v) => updateBlock(i, {...b, 'placement': v}),
            ),
          if (b['key'] == 'jesus')
            TextFormField(
              initialValue: '${b['durationMinutes'] ?? ''}',
              decoration: const InputDecoration(
                labelText: 'Продолжительность, минут (необязательно)',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => updateBlock(i, {
                ...b,
                'durationMinutes': v.isEmpty ? null : int.tryParse(v),
              }),
            ),
          if (b['key'] == 'jesus' && b['durationMinutes'] == null)
            TextFormField(
              initialValue: '${b['count'] ?? 100}',
              decoration: const InputDecoration(
                labelText: 'Повторений (1–10000)',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n > 0 && n <= 10000)
                  updateBlock(i, {...b, 'count': n});
              },
            ),
          if (b['kind'] == 'scripture')
            Wrap(
              spacing: 12,
              children: [
                for (final field in ['chapter', 'verseFrom', 'verseTo'])
                  SizedBox(
                    width: 130,
                    child: TextFormField(
                      initialValue:
                          '${b[field] ?? (field == 'chapter' ? 1 : '')}',
                      decoration: InputDecoration(
                        labelText: {
                          'chapter': 'Глава',
                          'verseFrom': 'Со стиха',
                          'verseTo': 'По стих',
                        }[field],
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        updateBlock(i, {...b, field: n});
                      },
                    ),
                  ),
              ],
            ),
          if (b['kind'] == 'psalter') ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: b['mode'] as String,
              decoration: const InputDecoration(labelText: 'Способ чтения'),
              items: const [
                DropdownMenuItem(
                  value: 'continuous',
                  child: Text('В своём темпе'),
                ),
                DropdownMenuItem(
                  value: 'scheduled',
                  child: Text('Своё расписание'),
                ),
                DropdownMenuItem(
                  value: 'liturgical',
                  child: Text('Богослужебное расписание'),
                ),
              ],
              onChanged: (m) => updateBlock(i, {
                ...b,
                'mode': m,
                'schedule':
                    b['schedule'] ??
                    {
                      '1': [1],
                      '2': [2],
                      '3': [3],
                      '4': [4],
                      '5': [5],
                      '6': [6],
                      '7': [7],
                    },
              }),
            ),
            if (b['mode'] == 'continuous')
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: b['unit'] as String,
                decoration: const InputDecoration(labelText: 'За один раз'),
                items: const [
                  DropdownMenuItem(value: 'kathisma', child: Text('Кафизма')),
                  DropdownMenuItem(value: 'statia', child: Text('Статия')),
                ],
                onChanged: (u) => updateBlock(i, {...b, 'unit': u}),
              ),
            if (b['mode'] == 'scheduled')
              for (var n = 1; n <= 7; n++)
                TextFormField(
                  key: ValueKey('${b['id']}:$n'),
                  initialValue: (circleMap(b['schedule'])['$n'] as List? ?? [])
                      .join(', '),
                  decoration: InputDecoration(
                    labelText:
                        '${['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][n - 1]}: номера кафизм через запятую',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final ns = v
                        .split(RegExp(r'[,\s]+'))
                        .where((v) => v.isNotEmpty)
                        .map(int.tryParse)
                        .toList();
                    if (ns.every((v) => v != null && v >= 1 && v <= 20))
                      updateBlock(i, {
                        ...b,
                        'schedule': {...circleMap(b['schedule']), '$n': ns},
                      });
                  },
                ),
            SwitchListTile(
              title: const Text('Поминовение усопших на славах'),
              value: b['departed'] == true,
              onChanged: (v) => updateBlock(i, {...b, 'departed': v}),
            ),
          ],
          Row(
            children: [
              IconButton(
                tooltip: 'Выше',
                onPressed: i == 0
                    ? null
                    : () {
                        final a = blocks;
                        final old = a[i - 1];
                        a[i - 1] = a[i];
                        a[i] = old;
                        updateBlocks(a);
                      },
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Ниже',
                onPressed: i == blocks.length - 1
                    ? null
                    : () {
                        final a = blocks;
                        final old = a[i + 1];
                        a[i + 1] = a[i];
                        a[i] = old;
                        updateBlocks(a);
                      },
                icon: const Icon(Icons.arrow_downward),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => updateBlocks(
                  blocks.where((v) => v['id'] != b['id']).toList(),
                ),
                child: const Text('Убрать'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _BlockPicker extends StatefulWidget {
  final List<CircleJson> choices;
  const _BlockPicker(this.choices);
  @override
  State<_BlockPicker> createState() => _BlockPickerState();
}

class _BlockPickerState extends State<_BlockPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final choices = widget.choices
        .where(
          (c) => (c['title'] as String).toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Найти молитву или чтение',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: choices.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(choices[i]['title'] as String),
              onTap: () => Navigator.pop(context, choices[i]),
            ),
          ),
        ),
      ],
    );
  }
}
