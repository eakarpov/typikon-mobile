import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../apiMapper/pomyannik.dart';
import '../apiMapper/session.dart';
import '../components/api_error_view.dart' show failureMessage;
import '../components/dossier.dart';
import '../dto/pomyannik.dart';
import '../utils/pomyannik_import.dart';

/// ЗАГРУЗКА СПИСКА ИМЁН.
///
/// Помянник заводят не по одному имени: список уже есть — в тетради, в
/// заметках, в переписке, — и переписывать его по строчке значит не завести
/// помянник вовсе.
///
/// **Разбор показывается до записи, а не после.** Чин, отделённый от имени, и
/// родство, взятое из скобок, — это догадки; догадка, которую видно и можно
/// поправить, не то же, что догадка, записанная молча. Поэтому здесь два шага:
/// сперва список разбирается и показывается, и только потом пишется.
///
/// **Столбец берётся у вкладки, а не угадывается.** На бумаге помянник
/// разграфлён надвое, и вписывают подряд в свой столбец; тот же порядок и здесь.
class PomyannikImportPage extends StatefulWidget {
  const PomyannikImportPage({super.key, required this.kind, this.vocabulary});

  /// `living` или `departed` — вкладка, с которой пришли.
  final String kind;

  /// Подменяется тестом: словарь чинов приходит по сети, а разбор без него
  /// проверять нечем. В приложении всегда `null` — словарь берётся с сервера.
  final Vocabulary? vocabulary;

  @override
  State<PomyannikImportPage> createState() => _PomyannikImportPageState();
}

class _PomyannikImportPageState extends State<PomyannikImportPage> {
  final TextEditingController _text = TextEditingController();

  Vocabulary _vocabulary = const Vocabulary();
  ImportResult? _parsed;

  /// Имена, снятые человеком: остаются на экране зачёркнутыми, чтобы было видно,
  /// что список не поредел сам собой.
  final Set<int> _dropped = {};

  bool _busy = false;
  Object? _error;

  bool get _departed => widget.kind == departed;

  @override
  void initState() {
    super.initState();
    final given = widget.vocabulary;
    if (given != null) {
      _vocabulary = given;
    } else {
      _loadVocabulary();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadVocabulary() async {
    try {
      final vocabulary = await getVocabulary();
      if (mounted) setState(() => _vocabulary = vocabulary);
    } catch (_) {
      // Без словаря чины не отделятся — имена запишутся целиком, и это лучше,
      // чем не записать ничего.
    }
  }

  Future<void> _openFile() async {
    try {
      final file = await openFile(acceptedTypeGroups: const [
        XTypeGroup(label: "Список имён", extensions: ["txt", "text", "csv", "md"]),
      ]);
      if (file == null) return;

      // utf8 с allowMalformed: список мог быть сохранён чем угодно, и падать на
      // одном негодном байте, потеряв весь файл, несоразмерно.
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      if (!mounted) return;
      _text.text = text;
      _parse();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(e, "файл не открылся"))),
      );
    }
  }

  void _parse() {
    setState(() {
      _dropped.clear();
      _parsed = parseNameList(
        _text.text,
        ranks: _vocabulary.ranks,
        kind: widget.kind,
      );
    });
  }

  List<ImportedName> get _kept {
    final parsed = _parsed;
    if (parsed == null) return const [];
    return [
      for (var i = 0; i < parsed.names.length; i++)
        if (!_dropped.contains(i)) parsed.names[i],
    ];
  }

  Future<void> _write() async {
    final kept = _kept;
    if (kept.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Пачками, как разрешает сервер: он же и называет предел в словаре.
      final limit = _vocabulary.limits.maxBatch;
      var written = 0;
      for (var from = 0; from < kept.length; from += limit) {
        final part = kept.skip(from).take(limit).toList();
        await addPersons([for (final name in part) name.toInput(widget.kind)]);
        written += part.length;
      }

      if (!mounted) return;
      Navigator.pop(context, written);
    } on SessionExpiredException {
      if (mounted) setState(() => _error = const SessionExpiredException());
    } catch (e) {
      if (!mounted) return;
      // Ни слова о записанном, пока не записано: всплывающее «готово» над
      // несохранённым списком родни — худшее из возможного.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(e, "список не записан"))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _departed ? "Список о упокоении" : "Список о здравии",
          style: const TextStyle(fontFamily: "OldStandard"),
        ),
      ),
      body: _error is SessionExpiredException
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "Сессия истекла. Войдите заново, и список запишется.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96.0),
              children: [
                _Source(
                  controller: _text,
                  onOpenFile: _openFile,
                  onParse: _parse,
                ),
                if (parsed != null) ..._review(parsed),
              ],
            ),
      floatingActionButton: parsed == null || _kept.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _write,
              icon: _busy
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    )
                  : const Icon(Icons.done),
              label: Text(_busy ? "Записываю…" : "Вписать ${_kept.length}"),
            ),
    );
  }

  List<Widget> _review(ImportResult parsed) {
    if (parsed.names.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "Имён в списке не нашлось. Каждое имя — своей строкой.",
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }

    final limits = _vocabulary.limits;
    final tooMany = _kept.length > limits.maxPersons;

    return [
      DossierSection(
        title: "Разобрано: ${parsed.names.length}",
        children: [
          if (parsed.headers.isNotEmpty)
            _Note("Заголовки столбцов пропущены: ${parsed.headers.length}"),
          if (parsed.duplicates.isNotEmpty)
            _Note("Повторы в списке взяты по разу: ${parsed.duplicates.length}"),
          if (tooMany)
            _Note(
              "В помянник помещается ${limits.maxPersons} имён — "
              "лишние сервер не примет.",
              alarming: true,
            ),
        ],
      ),
      for (var i = 0; i < parsed.names.length; i++)
        _NameRow(
          name: parsed.names[i],
          rank: _vocabulary.rank(parsed.names[i].rank),
          dropped: _dropped.contains(i),
          onToggle: () => setState(() {
            _dropped.contains(i) ? _dropped.remove(i) : _dropped.add(i);
          }),
        ),
    ];
  }
}

class _Source extends StatelessWidget {
  const _Source({
    required this.controller,
    required this.onOpenFile,
    required this.onParse,
  });

  final TextEditingController controller;
  final VoidCallback onOpenFile;
  final VoidCallback onParse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Каждое имя — своей строкой. Чин можно писать перед именем: "
            "«прот. Иоанна», «мл. Марии».",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12.0),
          TextField(
            controller: controller,
            maxLines: 8,
            minLines: 4,
            decoration: const InputDecoration(
              hintText: "Вставьте список или откройте файл",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onOpenFile,
                icon: const Icon(Icons.folder_open),
                label: const Text("Открыть файл"),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onParse,
                  icon: const Icon(Icons.checklist),
                  label: const Text("Разобрать"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({
    required this.name,
    required this.rank,
    required this.dropped,
    required this.onToggle,
  });

  final ImportedName name;
  final RankInfo? rank;
  final bool dropped;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final about = [
      if (rank != null) rank!.masculine.label,
      if (name.relation != null) name.relation!,
    ].join(" · ");

    return ListTile(
      dense: true,
      leading: Icon(
        dropped ? Icons.remove_circle_outline : Icons.check_circle_outline,
        color: dropped ? Theme.of(context).colorScheme.outline : null,
      ),
      title: Text(
        name.name,
        style: TextStyle(
          fontFamily: "OldStandard",
          decoration: dropped ? TextDecoration.lineThrough : null,
          color: dropped ? Theme.of(context).colorScheme.outline : null,
        ),
      ),
      // Исходная строка под именем: по ней человек узнаёт своё и видит, что
      // именно от неё отделили.
      subtitle: Text(
        about.isEmpty ? name.raw : "$about — ${name.raw}",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onToggle,
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.alarming = false});

  final String text;
  final bool alarming;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 2.0, 16.0, 2.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: alarming ? Theme.of(context).colorScheme.error : null,
            ),
      ),
    );
  }
}
