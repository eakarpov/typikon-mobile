import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/saints.dart';
import '../apiMapper/v2/errors.dart';
import '../components/async_view.dart';
import '../components/fusion_text.dart';
import '../components/pinch_zoom.dart';
import '../components/selection_menu.dart';
import '../utils/chant_style.dart';
import '../utils/reading_style.dart';
import '../utils/singing_labels.dart';

class SaintCorpusTarget {
  final String reader;
  final String id;
  final String title;
  final String? language;
  const SaintCorpusTarget({
    required this.reader,
    required this.id,
    required this.title,
    this.language,
  });
}

class SaintCorpusPage extends StatefulWidget {
  const SaintCorpusPage({super.key, required this.target, this.loader});
  final SaintCorpusTarget target;
  final Future<Map<String, dynamic>> Function()? loader;
  @override
  State<SaintCorpusPage> createState() => _SaintCorpusPageState();
}

class _SaintCorpusPageState extends State<SaintCorpusPage> {
  late Future<Map<String, dynamic>> _data;
  void _load() {
    _data = widget.loader?.call() ?? _fetch();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final target = widget.target;
    final response = target.reader == 'chant'
        ? await fetchSaintChant(target.id)
        : await fetchSaintService(target.id, target.language);
    if (response.statusCode != 200) {
      throwV2Error(response, 'Не удалось открыть текст');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.target.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: PinchZoom(
      child: Material(
        color: readingBackgroundColor(context),
        child: AsyncView<Map<String, dynamic>>(
          future: _data,
          message: 'Не удалось открыть текст.',
          onRetry: () => setState(_load),
          builder: (context, data) {
            final service = widget.target.reader == 'service';
            final rows = service ? (data['rows'] as List? ?? const []) : [data];
            final children = <Widget>[];
            Object? group;
            String? previousService;
            if (service) {
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Песнопения памяти · ${bookLabel(data['book'])}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }
            if (!service) {
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    [
                      unitLabel(data['unit']),
                      markerLabel(data['marker']),
                      if (data['tone'] != null) 'Глас ${data['tone']}',
                      if (data['book'] != null) bookLabel(data['book']),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }
            for (final raw in rows) {
              final row = Map<String, dynamic>.from(raw as Map);
              if (service && row['groupId'] != group) {
                group = row['groupId'];
                final currentService = row['service']?.toString();
                if (currentService != previousService) {
                  previousService = currentService;
                  children.add(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        serviceLabel(currentService),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  );
                }
                final label =
                    row['label']?.toString() ?? unitLabel(row['unit']);
                children.add(
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                );
              }
              if (service && markerLabel(row['marker']).isNotEmpty) {
                children.add(
                  Text(
                    markerLabel(row['marker']),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              if (row['rubric'] is String &&
                  (row['rubric'] as String).isNotEmpty) {
                children.add(
                  Text(
                    row['rubric'],
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              final text = row['text']?.toString() ?? '';
              children.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: text.trim().isEmpty
                      ? const Text(
                          'Текст этого фрагмента пока отсутствует в корпусе.',
                        )
                      : FusionTextWidgets(
                          text: text,
                          footnotes: const [],
                          fontFamily: chantFontFamily(
                            row['language']?.toString() ?? 'cu_gr',
                          ),
                        ),
                ),
              );
            }
            final canons = data['canons'] is List
                ? data['canons'] as List
                : const [];
            if (canons.isNotEmpty) {
              children.add(
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Каноны службы',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              );
              for (final raw in canons) {
                final c = Map<String, dynamic>.from(raw as Map);
                children.add(
                  ListTile(
                    title: Text(
                      c['tone'] == null ? 'Канон' : 'Канон · глас ${c['tone']}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/canons',
                      arguments: c['id']?.toString(),
                    ),
                  ),
                );
              }
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ReadingColumn(
                child: SelectionMenu.wordsOnly(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
