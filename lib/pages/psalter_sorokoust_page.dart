import 'package:flutter/material.dart';

import '../apiMapper/pomyannik.dart' show getPersons;
import '../apiMapper/session.dart' show SessionExpiredException;
import '../components/api_error_view.dart';
import '../components/sign_in_needed.dart';
import '../domain/psalter.dart';
import '../dto/pomyannik.dart' show Person, departed;
import '../pages/kathisma_page.dart' show kathismaRouteArgument;
import '../store/psalter_mode.dart';
import '../utils/pomyannik_labels.dart' show humanDate;

/// Сорокоуст по Псалтири: выбранное лицо помянника, день от даты преставления
/// и кафизма этого дня.
///
/// День преставления — первый, и считается он на клиенте по записанной в
/// помяннике дате (`Person.died`): другой арифметики здесь нет. Даты нет —
/// день честно неизвестен, а кафизма не открывается.
///
/// Имена берутся из помянника, поэтому экран личный: без входа —
/// [SignInNeeded], и кнопка чтения не притворяется.
class PsalterSorokoustPage extends StatefulWidget {
  /// Подменяется тестами; в приложении — `getPersons(kind: departed)`.
  final Future<List<Person>> Function()? personsLoader;

  const PsalterSorokoustPage({super.key, this.personsLoader});

  @override
  State<PsalterSorokoustPage> createState() => _PsalterSorokoustPageState();
}

class _PsalterSorokoustPageState extends State<PsalterSorokoustPage> {
  bool _loading = true;
  Object? _error;
  List<Person> _persons = const <Person>[];
  String? _selectedId;

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
    final selected = await psalterSorokoustPerson();
    try {
      final loader = widget.personsLoader ??
          () async => (await getPersons(kind: departed)).items;
      final persons = await loader();
      if (!mounted) return;
      setState(() {
        _persons = persons;
        _selectedId = selected;
        _loading = false;
      });
    } on SessionExpiredException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _choose() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text("О ком читаем", style: TextStyle(fontFamily: "OldStandard")),
        children: <Widget>[
          SizedBox(
            width: double.maxFinite,
            height: 360.0,
            child: ListView(
              children: <Widget>[
                for (final person in _persons)
                  ListTile(
                    title: Text(person.display,
                        style: const TextStyle(fontFamily: "OldStandard")),
                    subtitle: (person.died ?? "").isEmpty
                        ? null
                        : Text("† ${humanDate(person.died)}"),
                    onTap: () => Navigator.pop(dialogContext, person.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    await setPsalterSorokoustPerson(picked);
    if (!mounted) return;
    setState(() => _selectedId = picked);
  }

  void _openDayKathisma(int day) {
    final kathisma = sorokoustKathisma(day);
    Navigator.pushNamed(
      context,
      "/psalter/kathisma",
      arguments: kathismaRouteArgument(kathisma, departed: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Сорокоуст", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error is SessionExpiredException
              ? const SignInNeeded(
                  message: "Сорокоуст читается с именами из помянника, "
                      "а помянник хранится при вашей учётной записи.")
              : _error != null
                  ? ApiErrorView(
                      error: _error,
                      message: "Не удалось открыть помянник.",
                      onRetry: _load,
                    )
                  : _body(context, primary),
    );
  }

  Widget _body(BuildContext context, Color primary) {
    if (_persons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.hourglass_empty, size: 48.0),
              const SizedBox(height: 16.0),
              const Text(
                "О упокоении пока никто не вписан.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8.0),
              Text(
                "Впишите имена в помяннике — и сорокоуст посчитается сам.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final selected = _selectedId == null
        ? null
        : _persons.where((person) => person.id == _selectedId).firstOrNull;
    final day = sorokoustDay(selected?.died, DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        if (selected == null) ...<Widget>[
          const Text(
            "Усопший не выбран",
            style: TextStyle(fontFamily: "OldStandard", fontSize: 18.0),
          ),
          const SizedBox(height: 4.0),
          Text(
            "Выберите, о ком читать сорокоуст: день и кафизма посчитаются "
            "по дате преставления из помянника.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else ...<Widget>[
          Text(
            selected.display,
            style: const TextStyle(fontFamily: "OldStandard", fontSize: 20.0),
          ),
          if ((selected.died ?? "").isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text("† ${humanDate(selected.died)}"),
            ),
          const SizedBox(height: 16.0),
          if (day == null)
            Text(
              "День неизвестен, дата преставления не указана.",
              style: TextStyle(
                fontFamily: "OldStandard",
                fontSize: 16.0,
                color: primary,
              ),
            )
          else ...<Widget>[
            Text(
              "День $day из 40",
              style: TextStyle(
                fontFamily: "OldStandard",
                fontSize: 22.0,
                color: primary,
              ),
            ),
            const SizedBox(height: 12.0),
            FilledButton.icon(
              onPressed: () => _openDayKathisma(day),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text("Читать кафизму дня"),
            ),
          ],
        ],
        const SizedBox(height: 16.0),
        OutlinedButton.icon(
          onPressed: _choose,
          icon: const Icon(Icons.person_search_outlined),
          label: Text(selected == null ? "Выбрать…" : "Сменить…"),
        ),
      ],
    );
  }
}
