import 'dart:async';

import 'package:flutter/material.dart';

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
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String _query = "";
  String _typed = "";
  String? _subject;
  String? _status;

  AkathistFacets _facets = const AkathistFacets();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _typed = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = _typed.trim());
    });
  }

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
              child: TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: "Кому акафист: Богородице, Николаю",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _typed.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _typed = "";
                              _query = "";
                            });
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (_facets.subjectKinds.length > 1 || _facets.statuses.length > 1)
              SizedBox(
                height: 52.0,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  children: [
                    if (_facets.subjectKinds.length > 1)
                      _choice(
                        label: "кому",
                        value: _subject,
                        values: _facets.subjectKinds,
                        nameOf: subjectKindLabel,
                        onPicked: (value) => setState(() => _subject = value),
                      ),
                    if (_facets.statuses.length > 1)
                      _choice(
                        label: "достоинство",
                        value: _status,
                        values: _facets.statuses,
                        nameOf: akathistStatusLabel,
                        onPicked: (value) => setState(() => _status = value),
                      ),
                  ],
                ),
              ),
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

  Widget _choice({
    required String label,
    required String? value,
    required List<String> values,
    required String Function(String) nameOf,
    required void Function(String?) onPicked,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child: PopupMenuButton<String?>(
        onSelected: onPicked,
        itemBuilder: (context) => [
          PopupMenuItem<String?>(value: null, child: Text("любое $label")),
          ...values.map((item) => PopupMenuItem<String?>(value: item, child: Text(nameOf(item)))),
        ],
        child: Chip(
          label: Text(value == null ? label : nameOf(value)),
          avatar: Icon(value == null ? Icons.filter_list : Icons.check, size: 16.0),
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
