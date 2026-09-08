import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../apiMapper/singing.dart';
import '../components/paged_list.dart' show searchErrorView;
import '../components/table_of_contents.dart';
import '../dto/corpus.dart';
import '../store/models/models.dart';
import '../utils/chant_style.dart';
import '../utils/reading_style.dart';
import '../utils/singing_labels.dart';

/// Канон целиком: песни подряд, как в книге — ирмос, затем тропари.
///
/// **Номера песней не сплошные, и это не изъян разбора.** Второй песни нет ни у
/// кого, кроме Великого канона, а трипеснцы Триоди несут три и меньше. Номер
/// показывается тот, что стоит у песни в книге: «Песнь 3» после «Песни 1» — как
/// напечатано.
///
/// Оглавление песней — тем же готовым видом, каким листают день: у канона их
/// девять, и пролистывать их прокруткой на телефоне долго.
class CanonPage extends StatefulWidget {
  const CanonPage(context, {super.key, required this.id});

  final String id;

  @override
  State<CanonPage> createState() => _CanonPageState();
}

class _CanonPageState extends State<CanonPage> {
  late Future<CanonDetail> canon;
  final Map<int, GlobalKey> _odeKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    canon = getCanon(widget.id);
  }

  GlobalKey _keyFor(int ode) => _odeKeys.putIfAbsent(ode, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final fontSize =
        StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Канон", style: TextStyle(fontFamily: "OldStandard")),
        actions: [
          FutureBuilder<CanonDetail>(
            future: canon,
            builder: (context, future) {
              final odes = future.data?.odes ?? const <CanonOde>[];
              if (odes.length < 2) return const SizedBox.shrink();

              return IconButton(
                tooltip: "Песни",
                icon: const Icon(Icons.list),
                onPressed: () => showTableOfContents(
                  context,
                  odes
                      .map((ode) => TocEntry(
                            title: "Песнь ${ode.ode}",
                            anchorKey: _keyFor(ode.ode),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: FutureBuilder<CanonDetail>(
          future: canon,
          builder: (context, future) {
            if (future.hasError) {
              return searchErrorView(
                context,
                future.error!,
                "Не удалось открыть канон.",
                () => setState(_load),
              );
            }
            if (!future.hasData) return const Center(child: CircularProgressIndicator());

            return _body(context, future.data!, fontSize);
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, CanonDetail detail, double fontSize) {
    final canon = detail.canon;
    final font = chantFontFamily(canon.language);
    final small = Theme.of(context).textTheme.bodySmall;

    final address = <String>[
      bookLabel(canon.book),
      memoryAddress(
        book: canon.book,
        month: canon.month,
        day: canon.day,
        paschaOffset: canon.paschaOffset,
        weekday: canon.weekday,
        memoryTone: canon.memoryTone,
      ),
      serviceLabel(canon.service),
      if (canon.tone != null) "глас ${canon.tone}",
      canonRoleLabel(canon.role),
      languageLabel(canon.language),
    ].where((part) => part.isNotEmpty).join(" · ");

    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 40.0),
      children: [
        Text(
          canon.memory.isEmpty ? "Без метки памяти" : canon.memory,
          style: TextStyle(fontFamily: "OldStandard", fontSize: fontSize + 2.0),
        ),
        if (address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(address, style: small),
          ),
        // Лицо и надписание — разные вещи, и стоят порознь. Сверху то, с чем
        // надписание отождествлено; ниже — как эту же строку напечатала книга,
        // потому что напечатанное и есть свидетельство, а отождествление —
        // вывод из него, и он может быть неверен.
        if (canon.authorLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text("Творение: ${canon.authorLabel}", style: small),
          ),
        if ((canon.creator ?? "").isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              "Надписание книги: ${canon.creator}",
              style: small?.copyWith(fontFamily: "OldStandard"),
            ),
          ),
        if ((canon.acrostic ?? "").isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              "Краегранесие: ${canon.acrostic}",
              style: small?.copyWith(fontFamily: "OldStandard"),
            ),
          ),
        if (detail.odes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Text("Песней этого канона в корпусе нет.", style: small),
          ),
        ...detail.odes.map((ode) =>
            _Ode(ode: ode, anchorKey: _keyFor(ode.ode), fontSize: fontSize, font: font)),
      ],
    );
  }
}

class _Ode extends StatelessWidget {
  const _Ode({
    required this.ode,
    required this.anchorKey,
    required this.fontSize,
    required this.font,
  });

  final CanonOde ode;
  final GlobalKey anchorKey;
  final double fontSize;
  final String font;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: anchorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
          child: Text(
            // Номер книги, а не порядковый: пропуск здесь напечатан, а не наш.
            "Песнь ${ode.ode}",
            style: TextStyle(
              fontFamily: "OldStandard",
              fontWeight: FontWeight.bold,
              fontSize: fontSize + 1.0,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        if (ode.irmos.isNotEmpty)
          _Group(title: "Ирмос", lines: ode.irmos, fontSize: fontSize, font: font),
        if (ode.troparia.isNotEmpty)
          _Group(title: "Тропари", lines: ode.troparia, fontSize: fontSize, font: font),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.lines,
    required this.fontSize,
    required this.font,
  });

  final String title;
  final List<CanonLine> lines;
  final double fontSize;
  final String font;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4.0),
        ...lines.map((line) => _Line(line: line, fontSize: fontSize, font: font)),
        const SizedBox(height: 8.0),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line, required this.fontSize, required this.font});

  final CanonLine line;
  final double fontSize;
  final String font;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;

    final about = <String>[
      markerLabel(line.marker),
      if (line.repeat > 1) "${line.repeat} раза",
      // Текст подставлен из Ирмология: сказать об этом надо, иначе он выдаётся
      // за напечатанный здесь.
      if (line.borrowed) "текст по ссылке",
    ].where((part) => part.isNotEmpty).join(" · ");

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (about.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: Text(about, style: small?.copyWith(fontStyle: FontStyle.italic)),
            ),
          // Косая черта — перевод строки: так книга размечает строки песнопения.
          ...chantLines(line.text).map((row) => Text(
                row,
                style: TextStyle(
                  fontFamily: font,
                  fontSize: fontSize,
                  color: readingTextColor(context),
                ),
              )),
        ],
      ),
    );
  }
}
