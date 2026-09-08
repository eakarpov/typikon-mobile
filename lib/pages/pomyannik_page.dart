import 'package:flutter/material.dart';

import '../apiMapper/pomyannik.dart';
import '../apiMapper/session.dart';
import '../components/paged_list.dart';
import '../components/sign_in_needed.dart';
import '../dto/pomyannik.dart';
import '../utils/pomyannik_labels.dart';

/// РАЗВОРОТ ПОМЯННИКА: о здравии и о упокоении.
///
/// Это устройство помянника, а не отбор по признаку: на бумаге он так и
/// разграфлён, и вписывают имена не вперемешку, а подряд в свой столбец.
/// Оттого и кнопка «вписать» одна на вкладку — лишний выбор «куда» на каждом
/// имени это лишнее движение тридцать раз подряд.
///
/// **Записывается только по сети.** Отложенной очереди здесь нет и быть не
/// должно: несинхронизированное имя — это человек, которого хозяин считает
/// поминаемым, а узнаёт он об обратном тем, что не пришло напоминание о
/// сороковом дне. Нет связи — так и сказано, и кнопка не притворяется.
class PomyannikPage extends StatefulWidget {
  const PomyannikPage(context, {super.key});

  @override
  State<PomyannikPage> createState() => _PomyannikPageState();
}

class _PomyannikPageState extends State<PomyannikPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  /// Словарь чинов. Пока не пришёл — чины не подписаны, и это верно: лучше без
  /// чина, чем с чужим.
  Vocabulary _vocabulary = const Vocabulary();

  /// Меняется после всякой записи и правки: по нему `PagedList` перечитывает
  /// список с начала.
  int _token = 0;

  Object? _error;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadVocabulary();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadVocabulary() async {
    try {
      final vocabulary = await getVocabulary();
      if (mounted) setState(() => _vocabulary = vocabulary);
    } catch (_) {
      // Молчим: без словаря помянник читается, только без чинов.
    }
  }

  void _reload() => setState(() {
        _token++;
        _error = null;
      });

  Future<void> _add(String kind) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _AskName(),
    );
    if (name == null || name.trim().isEmpty) return;

    setState(() => _adding = true);
    try {
      await addPersons([
        {"name": name.trim(), "kind": kind},
      ]);
      if (!mounted) return;
      _reload();
    } on SessionExpiredException {
      if (mounted) setState(() => _error = const SessionExpiredException());
    } catch (e) {
      if (!mounted) return;
      // Имя не записано — так и говорим. Всплывающее «сохранено» над несохранённым
      // было бы худшим из возможного: о нём не узнают до пропущенного дня.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Имя не записано: $e")),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Помянник", style: TextStyle(fontFamily: "OldStandard")),
        actions: [
          IconButton(
            tooltip: "Ближайшее",
            icon: const Icon(Icons.event_outlined),
            onPressed: () => Navigator.pushNamed(context, "/pomyannik/upcoming"),
          ),
          IconButton(
            tooltip: "Записка",
            icon: const Icon(Icons.article_outlined),
            onPressed: () => Navigator.pushNamed(context, "/pomyannik/zapiska"),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: "О здравии"), Tab(text: "О упокоении")],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) => FloatingActionButton(
          onPressed: _adding ? null : () => _add(_tabs.index == 0 ? living : departed),
          tooltip: _tabs.index == 0 ? "Вписать о здравии" : "Вписать о упокоении",
          child: _adding
              ? const SizedBox(
                  width: 20.0, height: 20.0, child: CircularProgressIndicator(strokeWidth: 2.0))
              : const Icon(Icons.add),
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _error is SessionExpiredException
            ? const SignInNeeded(
                message: "Помянник хранится при вашей учётной записи и виден только вам.")
            : TabBarView(
                controller: _tabs,
                children: [
                  _Column(kind: living, token: _token, vocabulary: _vocabulary),
                  _Column(kind: departed, token: _token, vocabulary: _vocabulary),
                ],
              ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.kind, required this.token, required this.vocabulary});

  final String kind;
  final int token;
  final Vocabulary vocabulary;

  @override
  Widget build(BuildContext context) {
    return PagedList<Person>(
      resetToken: "$kind:$token",
      load: (offset) => getPersons(kind: kind, offset: offset),
      emptyMessage: kind == living
          ? "О здравии пока никто не вписан."
          : "О упокоении пока никто не вписан.",
      errorMessage: "Не удалось открыть помянник.",
      itemBuilder: (context, person) => _Row(person: person, vocabulary: vocabulary),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.person, required this.vocabulary});

  final Person person;
  final Vocabulary vocabulary;

  @override
  Widget build(BuildContext context) {
    final about = <String>[
      rankLabel(vocabulary, person),
      // Родство — для хозяина: оно помогает не спутать двух Николаев. В записку
      // оно не идёт, там поминают по имени.
      if ((person.relation ?? "").isNotEmpty) person.relation!,
      if (person.isDeparted && (person.died ?? "").isNotEmpty) "† ${humanDate(person.died)}",
    ].where((part) => part.isNotEmpty).toList();

    return ListTile(
      title: Text(person.display, style: const TextStyle(fontFamily: "OldStandard")),
      subtitle: about.isEmpty
          ? null
          : Text(about.join(", "), style: Theme.of(context).textTheme.bodySmall),
      onTap: () => Navigator.pushNamed(context, "/pomyannik", arguments: person.id),
    );
  }
}

/// Быстрая строка: одно имя, как его пишут в помяннике.
///
/// Всё прочее — чин, даты, именины — правится в карточке. Список с бумаги в
/// тридцать строк вписывают на сайте: там разбор показывается прежде записи, а
/// без него массовый ввод не меньшая работа, а худшая.
class _AskName extends StatefulWidget {
  const _AskName();

  @override
  State<_AskName> createState() => _AskNameState();
}

class _AskNameState extends State<_AskName> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Вписать имя", style: TextStyle(fontFamily: "OldStandard")),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: "Имя"),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
        TextButton(
          onPressed: () => Navigator.pop(context, _name.text),
          child: const Text("Вписать"),
        ),
      ],
    );
  }
}
