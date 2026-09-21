import 'package:flutter/material.dart';

import 'package:typikon/components/dossier.dart';

import '../apiMapper/pomyannik.dart';
import '../apiMapper/session.dart';
import '../components/api_error_view.dart';
import '../components/sign_in_needed.dart';
import '../dto/pomyannik.dart';
import '../utils/pomyannik_labels.dart';

/// Карточка лица: даты и то, что из них следует.
///
/// **Счёт приходит с сервера целиком.** День преставления считается первым,
/// оттого третий день — через двое суток, девятый — через восемь, сороковой —
/// через тридцать девять. Повторять это здесь мы не станем: ошибка вышла бы на
/// день и ровно в ту сторону, где день пропускают.
///
/// **Счёт этот — обычай, а не уставное предписание**, и страница обязана
/// сказать об этом словами: спорить с человеком о дне поминовения его родителя
/// у нас нет права.
///
/// **Всё посчитанное протухает в полночь.** «Новопреставленный» живёт сорок
/// дней, годовщина прибавляется в свой день; карточка, пролежавшая открытой
/// через полночь, перезапрашивается при возврате в приложение.
class PomyannikPersonPage extends StatefulWidget {
  const PomyannikPersonPage(context, {super.key, required this.id});

  final String id;

  @override
  State<PomyannikPersonPage> createState() => _PomyannikPersonPageState();
}

class _PomyannikPersonPageState extends State<PomyannikPersonPage> with WidgetsBindingObserver {
  late Future<PersonCard> card;
  PersonCard? _loaded;

  /// Правили или убирали — списку позади надо перечитаться.
  bool _changed = false;
  Vocabulary _vocabulary = const Vocabulary();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _loadVocabulary();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Карточка, оставленная открытой на ночь, назавтра неверна: «сороковой день
    // — завтра» превратится в «сегодня», а помета «новопреставленный» однажды
    // просто перестанет быть правдой.
    if (_loaded != null && _loaded!.staleOn(today())) setState(_load);
  }

  void _load() {
    card = getPerson(widget.id);
    card.then((value) {
      if (mounted) setState(() => _loaded = value);
    }).catchError((Object _) {});
  }

  Future<void> _loadVocabulary() async {
    try {
      final vocabulary = await getVocabulary();
      if (mounted) setState(() => _vocabulary = vocabulary);
    } catch (_) {}
  }

  Future<void> _edit(Person person) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => _EditPerson(person: person, vocabulary: _vocabulary),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _load();
        // Список позади тоже показывает имя и чин: вернувшись в него, хозяин
        // должен увидеть правку, а не прежнее.
        _changed = true;
      });
    }
  }

  Future<void> _remove(Person person) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Убрать имя?", style: TextStyle(fontFamily: "OldStandard")),
        content: Text("${person.display} — из помянника. Отменить это будет нечем."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Убрать")),
        ],
      ),
    );
    if (sure != true) return;

    try {
      await removePerson(person.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureMessage(e, "имя не убрано"))));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Системная «назад» и жест возвращают `null`, а не `_changed`: список после
    // правки имени показывал бы прежнее. Поэтому уход перехватываем и отдаём
    // признак сами — одним путём для кнопки в шапке, кнопки системы и жеста.
    //
    // Перехват включается, только когда есть о чём сообщить: `canPop: false`
    // гасит боковой жест возврата, и держать его выключенным всё время ради
    // случая, который может не наступить, незачем.
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          // Имени в заголовке нет нарочно: список недавних экранов — не то место,
          // где имени из чужого помянника стоит показываться через плечо.
          title: const Text("Помянник", style: TextStyle(fontFamily: "OldStandard")),
          actions: [
            if (_loaded != null) ...[
              IconButton(
                tooltip: "Править",
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(_loaded!.person),
              ),
              IconButton(
                tooltip: "Убрать",
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _remove(_loaded!.person),
              ),
            ],
          ],
        ),
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: FutureBuilder<PersonCard>(
            future: card,
            builder: (context, future) {
              if (future.error is SessionExpiredException) {
                return const SignInNeeded(
                  message: "Помянник хранится при вашей учётной записи и виден только вам.",
                );
              }
              if (future.hasError) {
                return ApiErrorView(
                  error: future.error,
                  message: "Не удалось открыть запись.",
                  onRetry: () => setState(_load),
                );
              }
              if (!future.hasData) return const Center(child: CircularProgressIndicator());

              return _Card(card: future.data!, vocabulary: _vocabulary);
            },
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card, required this.vocabulary});

  final PersonCard card;
  final Vocabulary vocabulary;

  @override
  Widget build(BuildContext context) {
    final person = card.person;
    final small = Theme.of(context).textTheme.bodySmall;
    final memorial = card.memorial;
    final sorokoust = card.sorokoust;

    final about = <String>[
      rankLabel(vocabulary, person),
      if ((person.relation ?? "").isNotEmpty) person.relation!,
    ].where((part) => part.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.display,
                style: const TextStyle(fontFamily: "OldStandard", fontSize: 20.0),
              ),
              if (about.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(about.join(", "), style: small),
                ),
              if (memorial?.newlyDeparted == true)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    "новопреставленный",
                    style: small?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
            ],
          ),
        ),
        if (memorial != null) ...[
          const DossierSection(title: "Дни поминовения"),
          _FactLine("Третий день", humanDate(memorial.third)),
          _FactLine("Девятый день", humanDate(memorial.ninth)),
          _FactLine("Сороковой день", humanDate(memorial.fortieth)),
          if (memorial.years > 0) _FactLine("Со дня преставления", years(memorial.years)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
            child: Text(
              "День преставления считается первым. Счёт этот повсеместный, но он обычай "
              "счисления, а не уставное предписание.",
              style: small,
            ),
          ),
        ],
        if (sorokoust != null) ...[
          // Отдельным разделом и под своим именем: сорокоуст считается со дня
          // заказа, а не со дня кончины, и заказанный на девятый день кончится
          // на сорок восьмой. Под одним заголовком с сороковым днём они слились
          // бы в одно, чем они не являются.
          const DossierSection(title: "Сорокоуст"),
          _FactLine("Начат", humanDate(sorokoust.from)),
          _FactLine("Оканчивается", humanDate(sorokoust.to)),
          _FactLine(
            sorokoust.done ? "Окончен" : "Идёт",
            sorokoust.done ? "" : "день ${sorokoust.passed} из 40, осталось ${sorokoust.left}",
          ),
          if ((person.sorokoust?.where ?? "").isNotEmpty)
            _FactLine("Где", person.sorokoust!.where!),
        ],
        // Раздел показывается, только если в нём есть чему быть. Заголовок над
        // пустотой обещает то, чего под ним нет.
        if ((person.born ?? "").isNotEmpty ||
            (person.baptized ?? "").isNotEmpty ||
            (person.died ?? "").isNotEmpty ||
            person.nameDay != null) ...[
          const DossierSection(title: "Даты"),
          if ((person.born ?? "").isNotEmpty) _FactLine("Рождение", humanDate(person.born)),
          if ((person.baptized ?? "").isNotEmpty) _FactLine("Крещение", humanDate(person.baptized)),
          if ((person.died ?? "").isNotEmpty) _FactLine("Преставление", humanDate(person.died)),
          if (person.nameDay != null) _NameDay(nameDay: person.nameDay!),
        ],
        // Именины считаются от дня рождения: ближайшая память после него. Без
        // дня рождения их не посчитать, и молчать об этом нельзя — пустота
        // читается как «памяти нет», а её просто не от чего отсчитать.
        if (person.nameDay == null && (person.born ?? "").isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0.0),
            child: Text(
              "Именины считаются по дню рождения — ближайшая память после него. "
              "Укажите день рождения, и они появятся сами.",
              style: small,
            ),
          ),
        const SizedBox(height: 24.0),
      ],
    );
  }
}

class _NameDay extends StatelessWidget {
  const _NameDay({required this.nameDay});

  final NameDay nameDay;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;

    // Подвижная память ходит вместе с Пасхой, и числа у неё нет вовсе: назвать
    // его здесь значило бы соврать про всякий другой год.
    final when = nameDay.movable
        ? "переходящая память"
        : (nameDay.month != null && nameDay.day != null
            ? humanDate("2000-${nameDay.month.toString().padLeft(2, "0")}-"
                "${nameDay.day.toString().padLeft(2, "0")}", withYear: false)
            : "");

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Именины", style: TextStyle(fontFamily: "OldStandard")),
              Text(when, style: const TextStyle(fontFamily: "OldStandard")),
            ],
          ),
          Text(
            [
              // «Посчитано нами» и «названо человеком» — разные вещи: у первого
              // мы могли и промахнуться, у второго спрашивать нечего.
              nameDay.source == "manual" ? "названы вами" : "посчитаны по дню рождения и святцам",
              if (nameDay.style == "old" && !nameDay.movable) "число месяцесловное",
            ].join(", "),
            style: small,
          ),
        ],
      ),
    );
  }
}


/// Строка «имя — значение»: не то же, что DossierLine, где пояснение стоит под
/// именем. Здесь два столбца, и сводить их в один виджет значило бы склеивать
/// разное ради экономии на строчках.
class _FactLine extends StatelessWidget {
  const _FactLine(this.title, this.value);

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(child: Text(title, style: const TextStyle(fontFamily: "OldStandard"))),
            const SizedBox(width: 12.0),
            Text(value, style: const TextStyle(fontFamily: "OldStandard")),
          ],
        ),
      );
}

/// Правка лица.
///
/// Уходит на сервер ЛИЦОМ ЦЕЛИКОМ, а не изменёнными полями: иначе пришлось бы
/// решать, что значит отсутствующее поле — «не трогай» или «сотри», — и на этом
/// вопросе рано или поздно теряется дата преставления.
///
/// Именины здесь не правятся: выбор памяти стоит на указателе святцев, которого
/// у приложения нет, и подставить вместо выбора догадку значило бы решить за
/// человека, чьё имя он носит. Правятся они на сайте.
class _EditPerson extends StatefulWidget {
  const _EditPerson({required this.person, required this.vocabulary});

  final Person person;
  final Vocabulary vocabulary;

  @override
  State<_EditPerson> createState() => _EditPersonState();
}

class _EditPersonState extends State<_EditPerson> {
  late Person _draft;
  late final TextEditingController _name;
  late final TextEditingController _churchName;
  late final TextEditingController _relation;
  late final TextEditingController _where;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.person;
    _name = TextEditingController(text: _draft.name);
    _churchName = TextEditingController(text: _draft.churchName ?? "");
    _relation = TextEditingController(text: _draft.relation ?? "");
    _where = TextEditingController(text: _draft.sorokoust?.where ?? "");
  }

  @override
  void dispose() {
    _name.dispose();
    _churchName.dispose();
    _relation.dispose();
    _where.dispose();
    super.dispose();
  }

  Future<void> _pickDate(String field, String? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current ?? "") ?? now,
      firstDate: DateTime(1800),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() => _draft = _withDate(field, today(picked)));
  }

  Person _withDate(String field, String? value) {
    switch (field) {
      case "born":
        return _draft.copyWith(born: value);
      case "baptized":
        return _draft.copyWith(baptized: value);
      case "died":
        return _draft.copyWith(died: value);
      default:
        return _draft.copyWith(
          sorokoust: value == null ? null : Sorokoust(from: value, where: _where.text.trim()),
        );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final person = _draft.copyWith(
        name: _name.text.trim(),
        churchName: _churchName.text.trim().isEmpty ? null : _churchName.text.trim(),
        relation: _relation.text.trim().isEmpty ? null : _relation.text.trim(),
        sorokoust: _draft.sorokoust == null
            ? null
            : Sorokoust(
                from: _draft.sorokoust!.from,
                where: _where.text.trim().isEmpty ? null : _where.text.trim(),
              ),
      );
      await savePerson(person);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      // Правка не записана — и сказано об этом, а не показано «сохранено».
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureMessage(e, "правка не записана"))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranks = widget.vocabulary.ranks.where((rank) => rank.suits(_draft.kind)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Правка", style: TextStyle(fontFamily: "OldStandard")),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? "…" : "Записать", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: "Имя"),
          ),
          TextField(
            controller: _churchName,
            decoration: const InputDecoration(
              labelText: "Имя наречения",
              helperText: "Если оно другое: «Георгий» при «Юрии»",
            ),
          ),
          TextField(
            controller: _relation,
            decoration: const InputDecoration(
              labelText: "Кем приходится",
              helperText: "Для вас, чтобы не спутать двух Николаев. В записку не идёт",
            ),
          ),
          const SizedBox(height: 16.0),
          DropdownButtonFormField<String>(
            initialValue: _draft.kind,
            decoration: const InputDecoration(labelText: "Раздел"),
            items: const [
              DropdownMenuItem(value: living, child: Text("О здравии")),
              DropdownMenuItem(value: departed, child: Text("О упокоении")),
            ],
            onChanged: (value) => setState(() {
              // Чин мог быть только живым или только усопшим — при переносе он
              // перестаёт подходить, и оставить его значило бы вписать в записку
              // «убиенного» о здравии.
              final rank = widget.vocabulary.rank(_draft.rank);
              _draft = _draft.copyWith(
                kind: value,
                rank: rank != null && !rank.suits(value ?? living) ? null : _draft.rank,
              );
            }),
          ),
          DropdownButtonFormField<String?>(
            initialValue: _draft.sex,
            decoration: const InputDecoration(labelText: "Пол"),
            items: const [
              DropdownMenuItem(value: null, child: Text("не указан")),
              DropdownMenuItem(value: "m", child: Text("мужской")),
              DropdownMenuItem(value: "f", child: Text("женский")),
            ],
            onChanged: (value) => setState(() => _draft = _draft.copyWith(sex: value)),
          ),
          if (ranks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text("Чины не загрузились — этот раз обойдёмся без чина."),
            )
          else
            DropdownButtonFormField<String?>(
              initialValue: widget.vocabulary.rank(_draft.rank)?.key,
              decoration: const InputDecoration(labelText: "Чин"),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text("без чина")),
                ...ranks.map((rank) => DropdownMenuItem<String?>(
                      value: rank.key,
                      child: Text(rank.formFor(_draft.sex).label),
                    )),
              ],
              onChanged: (value) => setState(() => _draft = _draft.copyWith(rank: value)),
            ),
          const SizedBox(height: 8.0),
          _DateField(
            label: "Рождение",
            value: _draft.born,
            onPick: () => _pickDate("born", _draft.born),
            onClear: () => setState(() => _draft = _draft.copyWith(born: null)),
          ),
          _DateField(
            label: "Крещение",
            value: _draft.baptized,
            onPick: () => _pickDate("baptized", _draft.baptized),
            onClear: () => setState(() => _draft = _draft.copyWith(baptized: null)),
          ),
          _DateField(
            label: "Преставление",
            value: _draft.died,
            helper: "Дата преставления переносит имя на заупокойный разворот",
            onPick: () => _pickDate("died", _draft.died),
            onClear: () => setState(() => _draft = _draft.copyWith(died: null)),
          ),
          _DateField(
            label: "Сорокоуст начат",
            value: _draft.sorokoust?.from,
            helper: "Со дня заказа, а не со дня преставления",
            onPick: () => _pickDate("sorokoust", _draft.sorokoust?.from),
            onClear: () => setState(() => _draft = _draft.copyWith(sorokoust: null)),
          ),
          if (_draft.sorokoust != null)
            TextField(
              controller: _where,
              decoration: const InputDecoration(labelText: "Где заказан"),
            ),
          const SizedBox(height: 24.0),
          Text(
            "Именины правятся на сайте: выбор памяти стоит на указателе святцев, и подставлять "
            "вместо выбора догадку значило бы решать за вас, чьё имя вы носите.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
    this.helper,
  });

  final String label;
  final String? value;
  final String? helper;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final set = (value ?? "").isNotEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        set ? humanDate(value) : (helper ?? "не указана"),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: set
          ? IconButton(
              tooltip: "Убрать дату",
              icon: const Icon(Icons.clear),
              onPressed: onClear,
            )
          : const Icon(Icons.event_outlined),
      onTap: onPick,
    );
  }
}
