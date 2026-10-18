import 'package:flutter/material.dart';

import '../apiMapper/ordo.dart';
import '../components/async_view.dart';
import '../components/pinch_zoom.dart';
import '../components/selection_menu.dart';
import '../dto/ordo_services.dart';
import '../utils/reading_style.dart';
import '../utils/selected_day.dart';

class OrdoPage extends StatefulWidget {
  final Future<OrdoServices> Function(DateTime)? loader;
  const OrdoPage({super.key, this.loader});

  @override
  State<OrdoPage> createState() => _OrdoPageState();
}

class _OrdoPageState extends State<OrdoPage>
    with WidgetsBindingObserver, SelectedDay<OrdoPage> {
  late Future<OrdoServices> _data;

  @override
  void loadDay(DateTime day) {
    _data = (widget.loader ?? getOrdoServices)(day);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Служба дня'),
      actions: [
        IconButton(
          tooltip: 'Выбрать дату',
          onPressed: pickDay,
          icon: const Icon(Icons.calendar_month),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(SelectedDay.keyOf(selectedDay)),
        ),
        Expanded(
          child: ColoredBox(
            color: readingBackgroundColor(context),
            child: PinchZoom(
              child: AsyncView<OrdoServices>(
                future: _data,
                message: 'Не удалось открыть службу дня.',
                onRetry: reloadSelectedDay,
                onRefresh: () {
                  reloadSelectedDay();
                  return settle(_data);
                },
                isEmpty: (data) => data.services.isEmpty,
                emptyMessage: 'На эту дату службы не собраны.',
                builder: (context, data) => SingleChildScrollView(
                  key: ValueKey(SelectedDay.keyOf(selectedDay)),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  child: SelectionMenu.wordsOnly(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final service in data.services) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              service.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (service.error != null)
                            Text('Служба не собрана: ${service.error}'),
                          if (service.error == null && service.sections.isEmpty)
                            const Text('Тексты этой службы не собраны.'),
                          for (final section in service.sections) ...[
                            if (section.title.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  section.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            for (final text in section.texts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ReadingText(text, churchSlavonic: true),
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
