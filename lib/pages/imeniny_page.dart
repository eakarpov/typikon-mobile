
import 'package:flutter/material.dart';

import '../components/faceted_search.dart';

import '../apiMapper/reference.dart';
import '../components/api_error_view.dart';
import '../components/paged_list.dart';
import '../dto/reference.dart';

/// Указатель имён: по какому имени в святцах есть кого поминать.
class ImeninyPage extends StatefulWidget {
  const ImeninyPage(context, {super.key});

  @override
  State<ImeninyPage> createState() => _ImeninyPageState();
}

class _ImeninyPageState extends State<ImeninyPage> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Именины", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: SearchQueryField(
              hintText: "Начало имени",
              onQuery: (query) => setState(() => _query = query),
            ),
          ),
          Expanded(
            child: PagedList<NameIndexEntry>(
              // Пустой запрос — не ошибка, а начало просмотра: указатель имён
              // листается целиком, и отбор его сужает, а не открывает.
              resetToken: _query,
              load: (offset) => getNames(query: _query, offset: offset),
              emptyMessage: "Такого имени в указателе нет.",
              errorMessage: "Не удалось загрузить указатель имён.",
              itemBuilder: (context, item) => ListTile(
                title: Text(item.name, style: const TextStyle(fontFamily: "OldStandard")),
                subtitle: Text("святых: ${item.count}"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, "/imeniny", arguments: item.name),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кого поминают под этим именем и когда.
class NamePage extends StatefulWidget {
  const NamePage(context, {super.key, required this.name});

  final String name;

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  late Future<NameEntry> entry;
  late int year;

  @override
  void initState() {
    super.initState();
    year = DateTime.now().year;
    _load();
  }

  void _load() {
    entry = getName(widget.name, year: year);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, style: const TextStyle(fontFamily: "OldStandard")),
      ),
      body: FutureBuilder<NameEntry>(
        future: entry,
        builder: (context, future) {
          if (future.hasError) {
            return errorViewFor(
              context,
              future.error!,
              "Не удалось найти это имя.",
              () => setState(_load),
            );
          }
          if (!future.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _body(context, future.data!);
        },
      ),
    );
  }

  Widget _body(BuildContext context, NameEntry data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
      children: [
        Text(
          "Дни памяти в ${data.year} году",
          style: TextStyle(
            fontFamily: "OldStandard",
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8.0),
        if (data.memories.isEmpty)
          const Text("Дней памяти под этим именем не нашлось.")
        else
          ...data.memories.map((memory) => _memory(context, memory)),
        const Divider(height: 32.0),
        Text(
          // Оговорка приходит от сервера, а не сочиняется здесь: она обязана
          // ехать вместе с датой, кто бы её ни взял.
          data.caveat,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _memory(BuildContext context, NameMemory memory) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        memory.saint.name,
        style: const TextStyle(fontFamily: "OldStandard"),
      ),
      subtitle: Text([
        _humanDate(memory.date),
        if (memory.movable) "переходящая память",
        // Догадка названа догадкой: имя вынуто из соборной памяти, где перечень
        // идёт вперемешку, и ошибиться там легко.
        if (memory.saint.isGuess) "имя выведено из соборной памяти — возможна ошибка",
      ].join(" · ")),
      onTap: memory.saint.slug.isEmpty
          ? null
          : () => Navigator.pushNamed(context, "/saints", arguments: memory.saint.slug),
    );
  }

  static const List<String> _months = [
    "января", "февраля", "марта", "апреля", "мая", "июня",
    "июля", "августа", "сентября", "октября", "ноября", "декабря",
  ];

  /// «2026-08-07» → «7 августа». Год не повторяем: он назван в заголовке.
  String _humanDate(String iso) {
    final parts = iso.split("-");
    if (parts.length != 3) return iso;
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null || month < 1 || month > 12) return iso;
    return "$day ${_months[month - 1]}";
  }
}
