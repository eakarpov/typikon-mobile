
import 'package:flutter/material.dart';

import '../components/faceted_search.dart';

import '../apiMapper/places.dart';
import '../components/paged_list.dart';
import '../dto/paged.dart';
import '../dto/place.dart';
import '../utils/place_labels.dart';

/// Указатель мест: где было названное в Писании и в чтениях.
///
/// **Ищет сервер, а не приложение.** Весь указатель — сто семьдесят килобайт
/// шестью запросами, и сортировать его пришлось бы `compareTo`, то есть по кодам
/// символов, где «Ё» уезжает от «Е». Сервер отдаёт по пятьдесят в русском
/// порядке и ищет по всем именам места разом, так что «Царьград» находит
/// Константинополь.
///
/// **Букв не показываем.** Сайт делит список по алфавиту потому, что рисует все
/// строки разом и ему нужны переходы по буквам; здесь страница по пятьдесят, и
/// заголовок буквы описывал бы не указатель, а то, что успело загрузиться.
///
/// **Отборы приходят с сервера**, как у канонов: заведут в корпусе новый род
/// места — он появится сам, а зашитый здесь перечень разошёлся бы молча.
class PlacesPage extends StatefulWidget {
  const PlacesPage(BuildContext? context, {super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {

  String _query = "";
  String? _kind;
  bool _scriptureOnly = false;

  PlaceFacets _facets = const PlaceFacets();



  /// Всё, от чего зависит выдача. Сменилось — список начинается заново.
  String get _token => "$_query|$_kind|$_scriptureOnly";

  Future<Paged<PlaceSummary>> _load(int offset) async {
    final page = await getPlaces(
      query: _query, kind: _kind, scriptureOnly: _scriptureOnly, offset: offset,
    );

    // Отборы приезжают с каждой страницей, но берём их с первой: перерисовывать
    // полосу посреди прокрутки незачем.
    if (mounted && offset == 0) setState(() => _facets = page.facets);

    return Paged<PlaceSummary>(
      items: page.items, total: page.total, limit: page.limit, offset: page.offset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Места", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
              child: SearchQueryField(
                // Подсказка называет прежнее имя нарочно: искать можно по
                // любому из имён места, и знать об этом неоткуда.
                hintText: "Название: Иерусалим, Царьград",
                onQuery: (query) => setState(() => _query = query),
              ),
            ),
            _filters(),
            Expanded(
              child: PagedList<PlaceSummary>(
                resetToken: _token,
                load: _load,
                emptyMessage: "Ни одного места не нашлось.",
                errorMessage: "Не удалось открыть указатель мест.",
                itemBuilder: (context, place) => _PlaceTile(place: place),
              ),
            ),
            const _Attribution(),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    return FacetBar(chips: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
        child: FilterChip(
          label: const Text("в Писании"),
          selected: _scriptureOnly,
          onSelected: (value) => setState(() => _scriptureOnly = value),
        ),
      ),
      // Отбор с одним значением ничего не отбирает, а место занимает.
      if (_facets.kinds.length > 1)
        FacetChoice<PlaceKindCount>(
          name: "род",
          anyLabel: "любой род",
          value: _facets.kinds.where((facet) => facet.code == _kind).firstOrNull,
          values: _facets.kinds,
          // В меню — со счётом, на метке — одним именем: счёт там не помещается.
          nameOf: (facet) => "${placeKindLabel(facet.code)} (${facet.total})",
          onPicked: (facet) => setState(() => _kind = facet?.code),
        ),
    ]);
  }
}

class _PlaceTile extends StatelessWidget {
  final PlaceSummary place;

  const _PlaceTile({required this.place});

  @override
  Widget build(BuildContext context) {
    final about = <String>[
      if (place.kind != null) placeKindLabel(place.kind),
      if (place.status != null && place.status != "extant") placeStatusLabel(place.status),
      if (place.scripture > 0) "в Писании: ${place.scripture}",
    ].where((part) => part.isNotEmpty).join("; ");

    return ListTile(
      title: Text(place.name, style: const TextStyle(fontFamily: "OldStandard")),
      subtitle: about.isEmpty
          ? null
          : Text(
              about,
              style: TextStyle(
                fontFamily: "OldStandard",
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(context, "/places", arguments: place.address),
    );
  }
}

/// Ссылка на источники сведений о местах.
///
/// Не вежливость, а условие лицензий: счёт упоминаний в Писании в каждой строке
/// выведен из собрания OpenBible, и показывающий его показывает и это.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
      child: Text(
        "Сведения о местах: OpenBible.info (CC BY 4.0), Pleiades (CC BY 3.0), "
        "Wikidata (CC0) и правка проекта.",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
