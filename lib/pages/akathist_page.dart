import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../apiMapper/singing.dart';
import '../components/async_view.dart';
import '../components/table_of_contents.dart';
import '../dto/corpus.dart';
import '../store/models/models.dart';
import '../utils/chant_style.dart';
import '../utils/reading_style.dart';
import '../utils/singing_labels.dart';

/// Акафист целиком: строфы в порядке чтения.
///
/// **Проимий — не кондак, хотя и подписан кондаком.** Вступительный кондак стоит
/// вне краегранесия, и акростишный «кондак 2» несёт то же число, что второй
/// проимий. Различает их род, а не номер, — потому подпись строится по роду.
///
/// **Рефрен показан один раз, вверху.** Им кончается каждый икос, и по нему
/// акафист опознают; повторённый под каждой строфой, он вытеснил бы сами строфы.
class AkathistPage extends StatefulWidget {
  const AkathistPage(context, {super.key, required this.id});

  final String id;

  @override
  State<AkathistPage> createState() => _AkathistPageState();
}

class _AkathistPageState extends State<AkathistPage> {
  late Future<AkathistDetail> akathist;
  final Map<int, GlobalKey> _stanzaKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// То же обновление, но жестом. Ждём ответа: иначе кольцо пропадёт раньше.
  Future<void> _refresh() {
    setState(_load);
    return settle(akathist);
  }

  void _load() {
    akathist = getAkathist(widget.id);
  }

  GlobalKey _keyFor(int index) => _stanzaKeys.putIfAbsent(index, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final fontSize =
        StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Акафист", style: TextStyle(fontFamily: "OldStandard")),
        actions: [
          FutureBuilder<AkathistDetail>(
            future: akathist,
            builder: (context, future) {
              final stanzas = future.data?.stanzas ?? const <AkathistStanza>[];
              if (stanzas.length < 2) return const SizedBox.shrink();

              return IconButton(
                tooltip: "Строфы",
                icon: const Icon(Icons.list),
                onPressed: () => showTableOfContents(
                  context,
                  stanzas
                      .map((stanza) => TocEntry(
                            title: stanzaLabel(stanza.unit, stanza.stanza, stanza.kind),
                            anchorKey: _keyFor(stanza.index),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: readingBackgroundColor(context),
        child: AsyncView<AkathistDetail>(
          future: akathist,
          message: "Не удалось открыть акафист.",
          onRetry: () => setState(_load),
          onRefresh: _refresh,
          builder: (context, data) => _body(context, data, fontSize),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AkathistDetail detail, double fontSize) {
    final akathist = detail.akathist;
    final small = Theme.of(context).textTheme.bodySmall;

    final about = <String>[
      subjectKindLabel(akathist.subjectKind),
      akathistStatusLabel(akathist.status),
      if (akathist.stanzas > 0) "строф ${akathist.stanzas}",
    ].where((part) => part.isNotEmpty).join(" · ");

    // Не ListView: тот строит детей лениво, и у раздела за экраном нет
    // контекста — оглавление по нему молча не прокручивало (см. days_page).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            akathist.title,
            style: TextStyle(fontFamily: "OldStandard", fontSize: fontSize + 2.0),
          ),
          if (about.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(about, style: small),
            ),
          if ((akathist.memory ?? "").isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text("напечатан в службе: ${akathist.memory}", style: small),
            ),
          if ((detail.sourceBook ?? "").isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text("Источник: ${detail.sourceBook}", style: small),
            ),
          if ((detail.refrainIkos ?? "").isNotEmpty)
            _Refrain(
              title: "Рефрен икосов",
              text: detail.refrainIkos!,
              fontSize: fontSize,
            ),
          if ((detail.refrainKontakion ?? "").isNotEmpty)
            _Refrain(
              title: "Рефрен кондаков",
              text: detail.refrainKontakion!,
              fontSize: fontSize,
            ),
          const Divider(height: 32.0),
          if (detail.stanzas.isEmpty)
            Text("Текста акафиста в корпусе нет.", style: small)
          else
            ...detail.stanzas.map((stanza) => _Stanza(
                  key: _keyFor(stanza.index),
                  stanza: stanza,
                  fontSize: fontSize,
                )),
          if (detail.prayers.isNotEmpty) ...[
            const Divider(height: 32.0),
            Text(
              "Молитвы при акафисте",
              style: TextStyle(fontFamily: "OldStandard", fontSize: fontSize),
            ),
            // Молитва при акафисте — не строфа: ни номера, ни места в акростихе.
            // Но печатается она здесь же, и читателю нужна здесь же.
            ...detail.prayers.map((prayer) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    prayer.display,
                    style: const TextStyle(fontFamily: "OldStandard"),
                  ),
                  subtitle: (prayer.incipit ?? "").isEmpty ? null : Text(prayer.incipit!),
                  onTap: () => Navigator.pushNamed(context, "/prayers", arguments: prayer.id),
                )),
          ],
        ],
      ),
    );
  }
}

class _Refrain extends StatelessWidget {
  const _Refrain({required this.title, required this.text, required this.fontSize});

  final String title;
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          ...chantLines(text).map((line) => Text(
                line,
                style: TextStyle(
                  fontFamily: chantFontFamily(null),
                  fontSize: fontSize,
                  height: readingLineHeight(context),
                  fontStyle: FontStyle.italic,
                  color: readingTextColor(context),
                ),
              )),
        ],
      ),
    );
  }
}

class _Stanza extends StatelessWidget {
  const _Stanza({super.key, required this.stanza, required this.fontSize});

  final AkathistStanza stanza;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                stanzaLabel(stanza.unit, stanza.stanza, stanza.kind),
                style: TextStyle(
                  fontFamily: "OldStandard",
                  fontSize: fontSize,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              // Недостающая буква краегранесия значит потерянную строфу — за тем
              // её и показываем.
              if ((stanza.letter ?? "").isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text("краегранесие ${stanza.letter}", style: small),
                ),
            ],
          ),
          if (stanza.isProoimion)
            Text("вступительный кондак, вне краегранесия", style: small),
          const SizedBox(height: 4.0),
          ...chantLines(stanza.text).map((line) => Text(
                line,
                style: TextStyle(
                  fontFamily: chantFontFamily(null),
                  fontSize: fontSize,
                  height: readingLineHeight(context),
                  color: readingTextColor(context),
                ),
              )),
        ],
      ),
    );
  }
}
