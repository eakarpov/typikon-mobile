import 'package:flutter/material.dart';

import '../apiMapper/pomyannik.dart';
import '../apiMapper/session.dart';
import '../components/api_error_view.dart';
import '../components/note_sheet.dart';
import '../components/sign_in_needed.dart';
import '../dto/pomyannik.dart';
import '../utils/pomyannik_labels.dart';

/// СБОРКА ЗАПИСКИ.
///
/// **Вид поминовения выбирается первым, и он же решает, кого можно вписать.**
/// Панихида о живых не служится, молебен об усопших — тоже. Показывать все имена
/// подряд и ловить ошибку потом значило бы переложить на человека работу, какую
/// у свечного ящика делает свечница.
///
/// **Предпросмотр считает сервер.** Церковнославянский родительный падеж стоит
/// на словаре личных имён и склонении по схеме — ни того, ни другого на телефоне
/// нет, и подделать это здесь нечем.
class PomyannikNotePage extends StatefulWidget {
  const PomyannikNotePage(context, {super.key});

  @override
  State<PomyannikNotePage> createState() => _PomyannikNotePageState();
}

class _PomyannikNotePageState extends State<PomyannikNotePage> {
  Vocabulary _vocabulary = const Vocabulary();
  List<Person> _persons = const [];

  final Set<String> _chosen = <String>{};
  NoteKindInfo? _kind;
  bool _cross = true;

  Object? _error;
  bool _loading = true;
  bool _building = false;
  bool _sending = false;
  NoteSheet? _sheet;
  String? _refusal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final vocabulary = await getVocabulary();
      // Оба разворота сразу: вид поминовения ещё не выбран, и прятать половину
      // помянника до выбора незачем.
      final alive = await getPersons(kind: living, offset: 0);
      final reposed = await getPersons(kind: departed, offset: 0);
      if (!mounted) return;

      setState(() {
        _vocabulary = vocabulary;
        _persons = [...alive.items, ...reposed.items];
        _kind ??= vocabulary.noteKinds.isEmpty ? null : vocabulary.noteKinds.first;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Кого можно вписать в этот вид поминовения. Прочие не прячутся, а
  /// показываются недоступными: пропавшее из списка имя читается как «его нет в
  /// помяннике», а оно там есть.
  bool _suits(Person person) => _kind?.accepts(person.kind) ?? true;

  Future<void> _preview() async {
    final kind = _kind;
    if (kind == null || _chosen.isEmpty) return;

    setState(() {
      _building = true;
      _refusal = null;
    });

    try {
      final sheet = await getNoteSheet(kind.key, _chosen.toList());
      if (mounted) setState(() => _sheet = sheet);
    } on SessionExpiredException {
      if (mounted) setState(() => _error = const SessionExpiredException());
    } catch (e) {
      // Отказ проверки — это ответ сервера словами: «панихида — заупокойное
      // поминовение, живых в него не вписывают: Николай». Его и показываем, а не
      // своё «не удалось».
      if (mounted) setState(() => _refusal = failureMessage(e, "записку собрать не вышло"));
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Записка", style: TextStyle(fontFamily: "OldStandard")),
        actions: [
          if (_sheet != null)
            IconButton(
              // Значок показывает СОСТОЯНИЕ, а не действие: крест на листе стоит
              // или не стоит. Прежде здесь было наоборот — «плюс», когда крест
              // уже надписан, — и читалось как «добавить ещё».
              tooltip: _cross ? "Печатать без креста" : "Надписать крестом",
              icon: Icon(_cross ? Icons.check_box_outlined : Icons.check_box_outline_blank),
              onPressed: () => setState(() => _cross = !_cross),
            ),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _body(),
      ),
      floatingActionButton: _sheet == null && _chosen.isNotEmpty && !_building
          ? FloatingActionButton.extended(
              onPressed: _preview,
              icon: const Icon(Icons.article_outlined),
              label: const Text("Собрать"),
            )
          : null,
    );
  }

  Widget _body() {
    if (_error is SessionExpiredException) {
      return const SignInNeeded(
        message: "Записка собирается из вашего помянника — для этого нужен вход.",
      );
    }
    if (_error != null) {
      return ApiErrorView(
        error: _error,
        message: "Не удалось открыть помянник.",
        onRetry: _load,
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());

    final sheet = _sheet;
    if (sheet != null) return _sheetView(sheet);

    return _chooser();
  }

  Widget _sheetView(NoteSheet sheet) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        NoteSheetView(sheet: sheet, vocabulary: _vocabulary, cross: _cross),
        NoteSheetCaveats(sheet: sheet, vocabulary: _vocabulary),
        if (sheet.span != null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              "Поминовение с ${humanDate(sheet.span!.from)} по ${humanDate(sheet.span!.to)}. "
              "Срок считается со дня подачи, а она ещё не случилась — на день подачи он сдвинется.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 24.0),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _sending ? null : () => setState(() => _sheet = null),
                child: const Text("Изменить"),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: FilledButton(
                onPressed: _sending ? null : _send,
                child: Text(_sending ? "…" : "Подать"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Text(
          "Подают по коду-приглашению, какой священник раздаёт сам — ссылкой, объявлением на "
          "стенде. Храма тут нет вовсе: оплат у нас нет, и записку принимает священник, а не "
          "храм, и отвечает за неё он сам.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Подать записку.
  ///
  /// Имена сервер возьмёт из помянника сам, по их идентификаторам, а не из того,
  /// что мы ему пришлём: иначе проверка имён, ради которой всё и затевалось, не
  /// значила бы ничего.
  Future<void> _send() async {
    final kind = _kind;
    if (kind == null) return;

    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _AskCode(),
    );
    if (code == null || code.trim().isEmpty) return;

    setState(() {
      _sending = true;
      _refusal = null;
    });

    try {
      await sendNote(kind.key, _chosen.toList(), code: code.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Записка подана")),
      );
      Navigator.pop(context);
    } on SessionExpiredException {
      if (mounted) setState(() => _error = const SessionExpiredException());
    } catch (e) {
      // «Приём не найден», «этого поминовения он не принимает», «слишком часто» —
      // всё это ответы сервера словами, и подменять их своими незачем.
      if (!mounted) return;
      final said = failureMessage(e, "записка не подана");
      setState(() => _refusal = said);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(said)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _chooser() {
    final kinds = _vocabulary.noteKinds;
    final limit = _vocabulary.limits.maxNamesInNote;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
          child: DropdownButtonFormField<String>(
            initialValue: _kind?.key,
            decoration: const InputDecoration(labelText: "Что совершается"),
            items: kinds
                .map((kind) => DropdownMenuItem(value: kind.key, child: Text(kind.label)))
                .toList(),
            onChanged: (value) => setState(() {
              _kind = kinds.firstWhere((kind) => kind.key == value);
              // Выбор вида отсеивает уже отмеченных: панихида о живых не
              // служится, и оставить их отмеченными значило бы собрать записку,
              // которую сервер всё равно не примет.
              _chosen.removeWhere((id) {
                final person = _persons.firstWhere((p) => p.id == id);
                return !_kind!.accepts(person.kind);
              });
            }),
          ),
        ),
        if ((_kind?.note ?? "").isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 0.0),
            child: Text(_kind!.note, style: Theme.of(context).textTheme.bodySmall),
          ),
        if (_refusal != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
            child: Text(
              _refusal!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
          child: Text(
            "Выбрано ${_chosen.length} из $limit",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        ..._persons.map((person) {
          final suits = _suits(person);
          final chosen = _chosen.contains(person.id);
          final full = !chosen && _chosen.length >= limit;

          return CheckboxListTile(
            value: chosen,
            enabled: suits && !full,
            title: Text(
              person.commemorated,
              style: const TextStyle(fontFamily: "OldStandard"),
            ),
            subtitle: Text(
              [
                person.isDeparted ? "о упокоении" : "о здравии",
                rankLabel(_vocabulary, person),
                if (!suits) "в этот вид поминовения не вписывают",
              ].where((part) => part.isNotEmpty).join(", "),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onChanged: (value) => setState(() {
              if (value == true) {
                _chosen.add(person.id);
              } else {
                _chosen.remove(person.id);
              }
            }),
          );
        }),
        const SizedBox(height: 80.0),
      ],
    );
  }
}

/// Код-приглашение священника.
///
/// Не поиск по справочнику: приём открывается по коду, какой священник раздаёт
/// сам, и искать его по храмам негде — право это личное, а не приходское.
class _AskCode extends StatefulWidget {
  const _AskCode();

  @override
  State<_AskCode> createState() => _AskCodeState();
}

class _AskCodeState extends State<_AskCode> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Кому подать", style: TextStyle(fontFamily: "OldStandard")),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _code,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Код-приглашение"),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          const SizedBox(height: 12.0),
          Text(
            "Код даёт сам священник — ссылкой или объявлением на стенде.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
        TextButton(
          onPressed: () => Navigator.pop(context, _code.text),
          child: const Text("Подать"),
        ),
      ],
    );
  }
}
