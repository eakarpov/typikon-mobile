import 'package:flutter/material.dart';

import '../apiMapper/reference.dart';
import '../components/api_error_view.dart';
import '../dto/reference.dart';

/// Разбор летописной датировки.
///
/// Пособие не для читателя чтений, а для того, кто держит в руках источник с
/// записью вроде «в лето 6712, индикта 7, месяца марта в 5 день» и хочет знать,
/// какой это год и цела ли сама запись.
///
/// Отвечает не «вот год», а что уцелело и что чему противоречит: запись, не
/// сошедшаяся ни на одном годе, — законный ответ, он значит описку в источнике.
class ChronologyPage extends StatefulWidget {
  const ChronologyPage(context, {super.key});

  @override
  State<ChronologyPage> createState() => _ChronologyPageState();
}

/// Что можно назвать. Подписи наши: сервер отдаёт коды.
const List<({String name, String label, String hint})> _fields = [
  (name: "leto", label: "Лето от Сотворения мира", hint: "6712"),
  (name: "indikt", label: "Индикт", hint: "1–15"),
  (name: "krugSolntsu", label: "Круг Солнцу", hint: "1–28"),
  (name: "krugLune", label: "Круг Луне", hint: "1–19"),
  (name: "vrutseleto", label: "Вруцелето", hint: "1–7"),
  (name: "osnovanie", label: "Основание", hint: "1–30"),
  (name: "epakta", label: "Эпакта", hint: "0–30"),
  (name: "month", label: "Месяц", hint: "1–12"),
  (name: "day", label: "Число", hint: "1–31"),
];

const List<String> _weekdays = [
  "понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье",
];

class _ChronologyPageState extends State<ChronologyPage> {
  final Map<String, TextEditingController> _controllers = {
    for (final field in _fields) field.name: TextEditingController(),
  };
  String? _weekday;
  Future<ChronologyAnswer>? _answer;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _conditions => {
        for (final entry in _controllers.entries)
          if (entry.value.text.trim().isNotEmpty) entry.key: entry.value.text.trim(),
        if (_weekday != null) "weekday": _weekday!,
      };

  void _solve() {
    final conditions = _conditions;
    setState(() {
      _answer = conditions.isEmpty ? null : getChronology(conditions);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Хронология", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 32.0),
        children: [
          Text(
            "Наберите то, что названо в записи. Чем больше условий, тем уже ответ; "
            "хватает и одного.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12.0),
          ..._fields.map(_field),
          const SizedBox(height: 8.0),
          DropdownButtonFormField<String>(
            initialValue: _weekday,
            decoration: const InputDecoration(
              labelText: "День недели",
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text("не назван")),
              ..._weekdays.map((day) => DropdownMenuItem(value: day, child: Text(day))),
            ],
            onChanged: (value) => setState(() => _weekday = value),
          ),
          const SizedBox(height: 16.0),
          FilledButton(onPressed: _solve, child: const Text("Разобрать")),
          const SizedBox(height: 16.0),
          if (_answer != null) _result(context),
        ],
      ),
    );
  }

  Widget _field(({String name, String label, String hint}) field) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: TextField(
          controller: _controllers[field.name],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  Widget _result(BuildContext context) {
    return FutureBuilder<ChronologyAnswer>(
      future: _answer,
      builder: (context, future) {
        if (future.hasError) {
          return errorViewFor(
            context,
            future.error!,
            "Не удалось разобрать датировку.",
            _solve,
          );
        }
        if (!future.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _answerBody(context, future.data!);
      },
    );
  }

  Widget _answerBody(BuildContext context, ChronologyAnswer data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.text,
          style: TextStyle(
            fontFamily: "OldStandard",
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        if (data.ignored.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              // Молча выброшенное условие дало бы ответ, выглядящий
              // подтверждённым тем, чего в переборе не было.
              "В переборе не участвовало (не удалось прочесть): "
              "${data.ignored.join(", ")}.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 12.0),
        ...data.survivors.map((candidate) => _candidate(context, candidate)),
        if (data.fixes.isNotEmpty) ...[
          const Divider(height: 24.0),
          Text(
            "Что мешало",
            style: TextStyle(
              fontFamily: "OldStandard",
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
            child: Text(
              // Поправка, а не «без индикта что-то есть»: с ней можно идти к
              // рукописи.
              "Какое чтение потребовалось бы на месте противоречащего условия.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ...data.fixes.take(10).map((fix) => _fix(context, fix)),
        ],
      ],
    );
  }

  Widget _candidate(BuildContext context, ChronologyCandidate candidate) {
    final day = candidate.day;
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(candidate.label,
                style: const TextStyle(fontFamily: "OldStandard", fontWeight: FontWeight.bold)),
            if (day != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text("${day.julian} юлианского счёта · ${day.civil} нынешним · ${day.weekday}"),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                "индикт ${candidate.marks.indikt} · круг Солнцу ${candidate.marks.krugSolntsu} · "
                "круг Луне ${candidate.marks.krugLune} · вруцелето ${candidate.marks.vrutseleto} "
                "(${candidate.marks.vrutseletoLetter}) · основание ${candidate.marks.osnovanie} · "
                "эпакта ${candidate.marks.epakta} · ключ границ ${candidate.marks.klyuchGranits}",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fix(BuildContext context, ChronologyFix fix) => Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Text(
          "${fix.label}: читать не «${fix.stated}», а «${fix.needed}» — "
          "и сходится на ${fix.candidate.label}",
        ),
      );
}
