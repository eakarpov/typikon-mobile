import 'dart:async';

import 'package:flutter/material.dart';

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
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String _query = "";
  String _typed = "";
  String? _kind;

  PrayerFacets _facets = const PrayerFacets();

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
              child: TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: "При ком или по началу",
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
            if (_facets.kinds.length > 1)
              SizedBox(
                height: 52.0,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                      child: PopupMenuButton<String?>(
                        onSelected: (value) => setState(() => _kind = value),
                        itemBuilder: (context) => [
                          const PopupMenuItem<String?>(value: null, child: Text("любой род")),
                          ..._facets.kinds.map((item) => PopupMenuItem<String?>(
                                value: item,
                                child: Text(prayerKindLabel(item)),
                              )),
                        ],
                        child: Chip(
                          label: Text(_kind == null ? "род" : prayerKindLabel(_kind!)),
                          avatar: Icon(
                            _kind == null ? Icons.filter_list : Icons.check,
                            size: 16.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
