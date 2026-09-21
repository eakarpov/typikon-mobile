
import 'package:flutter/material.dart';

import '../components/faceted_search.dart';

import '../apiMapper/singing.dart';
import '../components/paged_list.dart';
import '../dto/corpus.dart';
import '../dto/paged.dart';
import '../utils/singing_labels.dart';

/// Молитвы корпуса.
///
/// **Молитву называет тот, при ком она стоит.** Двести тридцать пять из тысячи
/// подписаны просто «Моли́тва», и перечень одних заголовков был бы перечнем
/// одинаковых строк: заголовком идёт владелец, подписью — род, номер и зачин.
class PrayersPage extends StatefulWidget {
  const PrayersPage(context, {super.key});

  @override
  State<PrayersPage> createState() => _PrayersPageState();
}

class _PrayersPageState extends State<PrayersPage> {

  String _query = "";
  String? _kind;

  PrayerFacets _facets = const PrayerFacets();



  Future<Paged<Prayer>> _load(int offset) async {
    final page = await getPrayers(query: _query, offset: offset, kind: _kind);
    if (mounted && offset == 0) setState(() => _facets = page.facets);

    return Paged<Prayer>(
      items: page.items, total: page.total, limit: page.limit, offset: page.offset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Молитвы", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
              child: SearchQueryField(
                hintText: "При ком или по началу",
                onQuery: (query) => setState(() => _query = query),
              ),
            ),
            FacetBar(chips: [
              // Отбор с одним значением ничего не отбирает, а место занимает.
              if (_facets.kinds.length > 1)
                FacetChoice<String>(
                  name: "род",
                  anyLabel: "любой род",
                  value: _kind,
                  values: _facets.kinds,
                  nameOf: prayerKindLabel,
                  onPicked: (value) => setState(() => _kind = value),
                ),
            ]),
            Expanded(
              child: PagedList<Prayer>(
                resetToken: "$_query|$_kind",
                load: _load,
                emptyMessage: "Ни одной молитвы не нашлось.",
                errorMessage: "Не удалось открыть молитвы.",
                itemBuilder: (context, prayer) => _PrayerTile(prayer: prayer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerTile extends StatelessWidget {
  const _PrayerTile({required this.prayer});

  final Prayer prayer;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;

    final about = <String>[
      prayer.display,
      prayerKindLabel(prayer.kind),
    ].where((part) => part.isNotEmpty).join(" · ");

    return ListTile(
      title: Text(
        (prayer.owner ?? "").isEmpty ? prayer.display : prayer.owner!,
        style: const TextStyle(fontFamily: "OldStandard"),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(about, style: small),
          // Начало текста — то единственное, чем две молитвы одного акафиста
          // различаются.
          if ((prayer.incipit ?? "").isNotEmpty) Text(prayer.incipit!, style: small),
        ],
      ),
      onTap: () => Navigator.pushNamed(context, "/prayers", arguments: prayer.id),
    );
  }
}
