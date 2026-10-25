import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../apiMapper/posledovanie.dart';
import '../apiMapper/singing.dart';
import '../dto/corpus.dart';
import 'canon_page.dart';
import '../components/async_view.dart';
import '../components/pinch_zoom.dart';
import '../components/selection_menu.dart';
import '../dto/posledovanie.dart';
import '../store/models/models.dart';
import '../utils/reading_style.dart';

/// Аргумент маршрута `/posledovanie` — одна строка, по образцу `/bible`:
/// `<key>|<lang>|<gender>|<заголовок>`. Собирается из правила дня и из
/// причастного списка, менять сигнатуру всюду ради одного экрана не хочется.
enum PosledovaniePart { whole, beforeCommunion, communionPrayers }

/// Первую молитву Василия Великого распознаём в обоих изданных слоях.
/// До неё — последование, от неё — молитвы; ничего не повторяется.
List<PosledovanieRow> communionRows(
  List<PosledovanieRow> rows,
  PosledovaniePart part,
) {
  if (part == PosledovaniePart.whole) return rows;
  final boundary = rows.indexWhere((row) {
    final label = (row.label ?? '').toLowerCase().replaceAll(
      RegExp(r'[\u0300-\u036f\u0483-\u0489\u2de0-\u2dff]'),
      '',
    );
    return RegExp(r'^(молитва\s+1(?:-|[,\s])|млтва\s+а[,\s])').hasMatch(label);
  });
  if (boundary < 0) {
    throw const FormatException('Не найдена граница молитв ко Причащению');
  }
  return part == PosledovaniePart.beforeCommunion
      ? rows.sublist(0, boundary)
      : rows.sublist(boundary);
}

int communionCanonIndex(List<PosledovanieRow> rows) => rows.indexWhere((row) {
  final label = (row.label ?? '').toLowerCase().replaceAll(
    RegExp(r'[\u0300-\u036f\u0483-\u0489\u2de0-\u2dff]'),
    '',
  );
  final text = row.text.toLowerCase().replaceAll(
    RegExp(r'[\u0300-\u036f\u0483-\u0489\u2de0-\u2dff]'),
    '',
  );
  // Уставное издание называет строку после канона «И абие»,
  // гражданское — «Песнь 9»; сам зачин «Достойно есть» общий.
  return label.startsWith('песнь') ||
      label.startsWith('пѣснь') ||
      text.startsWith('достойно');
});

String posledovanieRouteArgument(
  String key,
  String title, {
  String lang = "cu",
  String gender = "m",
  PosledovaniePart part = PosledovaniePart.whole,
}) =>
    "${part == PosledovaniePart.whole ? key : '$key~${part.name}'}|$lang|$gender|$title";

class PosledovanieRouteTarget {
  final String key;
  final String lang;
  final String gender;
  final String title;
  final PosledovaniePart part;

  const PosledovanieRouteTarget({
    required this.key,
    required this.lang,
    required this.gender,
    required this.title,
    this.part = PosledovaniePart.whole,
  });
}

/// Разбор аргумента маршрута. Негодный хвост — `null`, а не половина экрана:
/// не открыть последование лучше, чем открыть чужое.
PosledovanieRouteTarget? parsePosledovanieArgument(String raw) {
  final parts = raw.split("|");
  if (parts.length < 4 || parts[0].isEmpty) return null;
  final title = parts.sublist(3).join("|").trim();
  if (title.isEmpty) return null;
  final keyParts = parts[0].split('~');
  final selected = keyParts.length == 1
      ? PosledovaniePart.whole
      : PosledovaniePart.values
            .where((p) => p.name == keyParts.last)
            .firstOrNull;
  if (selected == null) return null;
  return PosledovanieRouteTarget(
    key: keyParts.first,
    part: selected,
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
  final PosledovaniePart part;

  /// Подменяется тестами; в приложении — запрос к `/api/v2/posledovanie`.
  final Future<Posledovanie> Function()? loader;
  final Future<CanonDetail> Function()? canonLoader;

  const PosledovaniePage(
    BuildContext? context, {
    super.key,
    required this.title,
    required this.posledovanieKey,
    this.lang = "cu",
    this.gender = "m",
    this.part = PosledovaniePart.whole,
    this.loader,
    this.canonLoader,
  });

  @override
  State<PosledovaniePage> createState() => _PosledovaniePageState();
}

class _PosledovaniePageState extends State<PosledovaniePage> {
  late Future<Posledovanie> posledovanie;
  Future<CanonDetail?>? _communionCanon;
  bool get _withCanon =>
      widget.posledovanieKey == 'ko-prichashcheniyu' &&
      widget.part != PosledovaniePart.communionPrayers;

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
    if (_withCanon) {
      _communionCanon =
          (widget.canonLoader?.call() ??
                  getCanon('molebny-kanon-ko-prichashcheniyu'))
              .then<CanonDetail?>((c) => c)
              .catchError((Object _) => null);
    }
    posledovanie =
        (widget.loader?.call() ??
                getPosledovanie(
                  widget.posledovanieKey,
                  lang: widget.lang,
                  gender: widget.gender,
                ))
            .then(
              (data) => Posledovanie(
                key: data.key,
                lang: data.lang,
                rows: communionRows(data.rows, widget.part),
              ),
            );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontFamily: "OldStandard"),
        ),
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
    final canonIndex = _withCanon ? communionCanonIndex(data.rows) : -1;

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
                child: Text(
                  "Рядов этого последования в ответе нет.",
                  style: small,
                ),
              ),
            if (_withCanon && canonIndex < 0)
              const Text('Место канона в последовании не найдено.'),
            for (var i = 0; i < data.rows.length; i++) ...[
              if (i == canonIndex)
                FutureBuilder<CanonDetail?>(
                  future: _communionCanon,
                  builder: (context, snapshot) =>
                      snapshot.connectionState != ConnectionState.done
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        )
                      : snapshot.data == null
                      ? Column(
                          children: [
                            const Text('Канон ко Причащению не загружен.'),
                            TextButton(
                              onPressed: () => setState(_load),
                              child: const Text('Повторить'),
                            ),
                          ],
                        )
                      : EmbeddedCanon(snapshot.data!),
                ),
              PosledovanieRowView(row: data.rows[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class PosledovanieRowView extends StatelessWidget {
  const PosledovanieRowView({
    super.key,
    required this.row,
    this.showLabel = true,
  });

  final PosledovanieRow row;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final fontSize = StoreProvider.of<AppState>(
      context,
    ).state.settings.fontSize.toDouble();
    final small = Theme.of(context).textTheme.bodySmall;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel && (row.label ?? "").isNotEmpty)
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
            Text(
              "по ${row.repeatCount}",
              style: small?.copyWith(fontStyle: FontStyle.italic),
            ),
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
