import 'package:flutter/material.dart';

import '../apiMapper/pericopes.dart';
import '../components/paged_list.dart';
import '../dto/pericope.dart';

/// Указатель зачал: что Устав назначает читать и когда.
///
/// Листается без запроса — тем и отличается от поиска: список зачал сам по себе
/// и есть содержимое раздела, а отбор его сужает, а не открывает.
class PericopesPage extends StatefulWidget {
  const PericopesPage(context, {super.key});

  @override
  State<PericopesPage> createState() => _PericopesPageState();
}

/// Разделы устава, по которым зачала и различаются.
const Map<String, String> _sources = {
  "gospel": "Евангелие",
  "apostle": "Апостол",
  "paremia": "Паримии",
};

class _PericopesPageState extends State<PericopesPage> {
  /// `null` — все разделы. Отдельная кнопка «Все» нужна: без неё читатель,
  /// выбравший Евангелие, не вернётся к полному списку.
  String? source;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Зачала", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 4.0),
            child: Row(
              children: [
                _chip(null, "Все"),
                ..._sources.entries.map((entry) => _chip(entry.key, entry.value)),
              ],
            ),
          ),
          Expanded(
            child: PagedList<PericopeEntry>(
              // Смена отбора начинает список заново — иначе к евангельским
              // зачалам дописались бы апостольские.
              resetToken: source ?? "all",
              load: (offset) => getPericopes(source: source, offset: offset),
              emptyMessage: "Зачал в этом разделе не нашлось.",
              errorMessage: "Не удалось загрузить указатель зачал.",
              itemBuilder: (context, item) => _tile(context, item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String? value, String label) => Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontFamily: "OldStandard")),
          selected: source == value,
          onSelected: (_) => setState(() => source = value),
        ),
      );

  Widget _tile(BuildContext context, PericopeEntry item) {
    final where = item.occasions.join("; ");
    return ListTile(
      title: Text(
        item.label,
        style: const TextStyle(fontFamily: "OldStandard", fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.ranges.isNotEmpty) Text(item.rangesLabel),
          // Когда читается — свободная проза источника, а не перечисление.
          // Показываем как есть и разбирать не беремся.
          if (where.isNotEmpty)
            Text(where, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      isThreeLine: where.isNotEmpty && item.ranges.isNotEmpty,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(context, "/pericope", arguments: item.id),
    );
  }
}
