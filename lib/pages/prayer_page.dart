import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../apiMapper/singing.dart';
import '../components/paged_list.dart' show searchErrorView;
import '../dto/corpus.dart';
import '../store/models/models.dart';
import '../utils/chant_style.dart';
import '../utils/reading_style.dart';
import '../utils/singing_labels.dart';

/// Молитва целиком.
///
/// **«При ком» ведёт на акафист и никуда — при памяти.** Страницы памяти у нас
/// нет, как нет её и на сайте; строка, ведущая в пустоту, хуже строки, никуда не
/// ведущей.
class PrayerPage extends StatefulWidget {
  const PrayerPage(context, {super.key, required this.id});

  final String id;

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> {
  late Future<PrayerDetail> prayer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    prayer = getPrayer(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize =
        StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Молитва", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: readingBackgroundColor(context),
        child: FutureBuilder<PrayerDetail>(
          future: prayer,
          builder: (context, future) {
            if (future.hasError) {
              return searchErrorView(
                context,
                future.error!,
                "Не удалось открыть молитву.",
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

  Widget _body(BuildContext context, PrayerDetail detail, double fontSize) {
    final prayer = detail.prayer;
    final small = Theme.of(context).textTheme.bodySmall;
    final font = chantFontFamily(detail.language);

    final about = <String>[
      prayerKindLabel(prayer.kind),
      languageLabel(detail.language),
    ].where((part) => part.isNotEmpty).join(" · ");

    final owner = (prayer.owner ?? "").isEmpty ? null : prayer.owner!;
    final leadsToAkathist = prayer.kind == "akathist" && (prayer.ownerId ?? "").isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 40.0),
      children: [
        Text(
          prayer.display,
          style: TextStyle(fontFamily: "OldStandard", fontSize: fontSize + 2.0),
        ),
        if (about.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(about, style: small),
          ),
        if (owner != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: leadsToAkathist
                ? InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      "/akathists",
                      arguments: prayer.ownerId,
                    ),
                    child: Text(
                      owner,
                      style: TextStyle(
                        fontFamily: "OldStandard",
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Text(owner, style: const TextStyle(fontFamily: "OldStandard")),
          ),
        if ((detail.sourceBook ?? "").isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text("Источник: ${detail.sourceBook}", style: small),
          ),
        const Divider(height: 32.0),
        if (detail.text.isEmpty)
          Text("Текста молитвы в корпусе нет.", style: small)
        else
          ...chantLines(detail.text).map((line) => Text(
                line,
                style: TextStyle(
                  fontFamily: font,
                  fontSize: fontSize,
                  height: readingLineHeight(context),
                  color: readingTextColor(context),
                ),
              )),
        if (detail.siblings.isNotEmpty) ...[
          const Divider(height: 32.0),
          // Книга печатает молитвы вереницей, и читающий вторую обыкновенно
          // хочет и первую.
          Text(
            "Здесь же напечатаны",
            style: TextStyle(fontFamily: "OldStandard", fontSize: fontSize),
          ),
          ...detail.siblings.map((sibling) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  sibling.display,
                  style: const TextStyle(fontFamily: "OldStandard"),
                ),
                onTap: () => Navigator.pushReplacementNamed(
                  context,
                  "/prayers",
                  arguments: sibling.id,
                ),
              )),
        ],
      ],
    );
  }
}
