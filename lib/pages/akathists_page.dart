
import 'package:flutter/material.dart';

import '../components/faceted_search.dart';

import '../apiMapper/singing.dart';
import '../components/paged_list.dart';
import '../dto/corpus.dart';
import '../dto/paged.dart';
import '../utils/singing_labels.dart';

/// Акафисты корпуса.
///
/// **Уставом положен один — Великий; остальные тысяча сто один в сборку служб
/// не идут.** Сказать это надо не оговоркой внизу, а у каждого имени: раздел
/// похож на устав и им не является, и перечень без пометы обещал бы читателю
/// обратное.
class AkathistsPage extends StatefulWidget {
  const AkathistsPage(context, {super.key});

  @override
  State<AkathistsPage> createState() => _AkathistsPageState();
}

class _AkathistsPageState extends State<AkathistsPage> {

  String _query = "";
  String? _subject;
  String? _status;

  AkathistFacets _facets = const AkathistFacets();



  Future<Paged<Akathist>> _load(int offset) async {
    final page = await getAkathists(
      query: _query, offset: offset, subject: _subject, status: _status,
    );
    if (mounted && offset == 0) setState(() => _facets = page.facets);

    return Paged<Akathist>(
      items: page.items, total: page.total, limit: page.limit, offset: page.offset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Акафисты", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
              child: SearchQueryField(
                hintText: "Кому акафист: Богородице, Николаю",
                onQuery: (query) => setState(() => _query = query),
              ),
            ),
            FacetBar(chips: [
              // Отбор с одним значением ничего не отбирает, а место занимает.
              if (_facets.subjectKinds.length > 1)
                FacetChoice<String>(
                  name: "кому",
                  anyLabel: "любое кому",
                  value: _subject,
                  values: _facets.subjectKinds,
                  nameOf: subjectKindLabel,
                  onPicked: (value) => setState(() => _subject = value),
                ),
              if (_facets.statuses.length > 1)
                FacetChoice<String>(
                  name: "достоинство",
                  anyLabel: "любое достоинство",
                  value: _status,
                  values: _facets.statuses,
                  nameOf: akathistStatusLabel,
                  onPicked: (value) => setState(() => _status = value),
                ),
            ]),
            Expanded(
              child: PagedList<Akathist>(
                resetToken: "$_query|$_subject|$_status",
                load: _load,
                emptyMessage: "Ни одного акафиста не нашлось.",
                errorMessage: "Не удалось открыть акафисты.",
                itemBuilder: (context, akathist) => _AkathistTile(akathist: akathist),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _AkathistTile extends StatelessWidget {
  const _AkathistTile({required this.akathist});

  final Akathist akathist;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;

    final about = <String>[
      subjectKindLabel(akathist.subjectKind),
      akathistStatusLabel(akathist.status),
      if (akathist.stanzas > 0) "строф ${akathist.stanzas}",
    ].where((part) => part.isNotEmpty).join(" · ");

    return ListTile(
      title: Text(akathist.title, style: const TextStyle(fontFamily: "OldStandard")),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            about,
            // Уставный виден сразу: он один на тысячу с лишним, и глазами его
            // иначе не найти.
            style: akathist.isUstavny
                ? small?.copyWith(color: Theme.of(context).colorScheme.primary)
                : small,
          ),
          if ((akathist.memory ?? "").isNotEmpty)
            Text("напечатан в службе: ${akathist.memory}", style: small),
        ],
      ),
      onTap: () => Navigator.pushNamed(context, "/akathists", arguments: akathist.id),
    );
  }
}
