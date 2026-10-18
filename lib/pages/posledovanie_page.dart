import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../apiMapper/posledovanie.dart';
import '../components/async_view.dart';
import '../components/pinch_zoom.dart';
import '../components/selection_menu.dart';
import '../dto/posledovanie.dart';
import '../store/models/models.dart';
import '../utils/reading_style.dart';

/// Аргумент маршрута `/posledovanie` — одна строка, по образцу `/bible`:
/// `<key>|<lang>|<gender>|<заголовок>`. Собирается из правила дня и из
/// причастного списка, менять сигнатуру всюду ради одного экрана не хочется.
String posledovanieRouteArgument(
  String key,
  String title, {
  String lang = "cu",
  String gender = "m",
}) =>
    "$key|$lang|$gender|$title";

class PosledovanieRouteTarget {
  final String key;
  final String lang;
  final String gender;
  final String title;

  const PosledovanieRouteTarget({
    required this.key,
    required this.lang,
    required this.gender,
    required this.title,
  });
}

/// Разбор аргумента маршрута. Негодный хвост — `null`, а не половина экрана:
/// не открыть последование лучше, чем открыть чужое.
PosledovanieRouteTarget? parsePosledovanieArgument(String raw) {
  final parts = raw.split("|");
  if (parts.length < 4 || parts[0].isEmpty) return null;
  final title = parts.sublist(3).join("|").trim();
  if (title.isEmpty) return null;
  return PosledovanieRouteTarget(
    key: parts[0],
    lang: parts[1].isEmpty ? "cu" : parts[1],
    gender: parts[2] == "f" ? "f" : "m",
    title: title,
  );
}

/// Чтение последования рядами: заголовок, лицо, текст, рубрика, поклон.
///
/// По образцу канона (`lib/pages/canon_page.dart`), но без оглавления: рядов
/// у последования на один вечер немного, и листаются они одной прокруткой.
/// Выделение — только ударение и системные пункты (`SelectionMenu.wordsOnly`):
/// заметки и сообщения об ошибке пишутся на тексты библиотеки по её
/// идентификатору, а последование живёт своей ручкой и такого идентификатора
/// не имеет.
class PosledovaniePage extends StatefulWidget {
  final String title;
  final String posledovanieKey;
  final String lang;
  final String gender;

  /// Подменяется тестами; в приложении — запрос к `/api/v2/posledovanie`.
  final Future<Posledovanie> Function()? loader;

  const PosledovaniePage(
    context, {
    super.key,
    required this.title,
    required this.posledovanieKey,
    this.lang = "cu",
    this.gender = "m",
    this.loader,
  });

  @override
  State<PosledovaniePage> createState() => _PosledovaniePageState();
}

class _PosledovaniePageState extends State<PosledovaniePage> {
  late Future<Posledovanie> posledovanie;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// То же обновление, но жестом. Ждём ответа: иначе кольцо пропадёт раньше.
  Future<void> _refresh() {
    setState(_load);
    return settle(posledovanie);
  }

  void _load() {
    posledovanie = widget.loader?.call() ??
        getPosledovanie(widget.posledovanieKey, lang: widget.lang, gender: widget.gender);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontFamily: "OldStandard")),
      ),
      body: PinchZoom(
        child: Container(
          color: readingBackgroundColor(context),
          child: AsyncView<Posledovanie>(
            future: posledovanie,
            message: "Не удалось открыть последование.",
            onRetry: () => setState(_load),
            onRefresh: _refresh,
            builder: (context, data) => _body(context, data),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Posledovanie data) {
    final small = Theme.of(context).textTheme.bodySmall;

    // Не ListView: как у канона — содержимое целиком, чтобы SelectionArea
    // видело все ряды, а не только построенные.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 40.0),
      child: SelectionMenu.wordsOnly(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Рядов этого последования в ответе нет.", style: small),
              ),
            for (final row in data.rows) _RowView(row: row),
          ],
        ),
      ),
    );
  }
}

class _RowView extends StatelessWidget {
  const _RowView({required this.row});

  final PosledovanieRow row;

  @override
  Widget build(BuildContext context) {
    final fontSize =
        StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble();
    final small = Theme.of(context).textTheme.bodySmall;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((row.label ?? "").isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Text(
                row.label!,
                style: TextStyle(
                  fontFamily: "OldStandard",
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize + 1.0,
                  color: primary,
                ),
              ),
            ),
          if ((row.lead ?? "").isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: Text("${row.lead}:", style: small),
            ),
          if (row.text.isNotEmpty) ReadingText(row.text, churchSlavonic: true),
          if (row.repeatCount != null && row.repeatCount! > 1)
            Text("по ${row.repeatCount}", style: small?.copyWith(fontStyle: FontStyle.italic)),
          if (row.poklon)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text("(поклон)", style: small?.copyWith(color: primary)),
            ),
          if ((row.note ?? "").isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                row.note!,
                style: small?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}
