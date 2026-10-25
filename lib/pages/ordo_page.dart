import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../apiMapper/ordo.dart';
import '../apiMapper/ordo_scripture.dart';
import '../components/async_view.dart';
import '../components/pinch_zoom.dart';
import '../components/selection_menu.dart';
import '../dto/ordo_services.dart';
import '../domain/ordo_package.dart';
import '../utils/reading_style.dart';
import '../utils/selected_day.dart';

class OrdoPage extends StatefulWidget {
  final Future<OrdoServices> Function(DateTime)? loader;
  final Future<XFile?> Function()? pickPackage;
  const OrdoPage({super.key, this.loader, this.pickPackage});

  @override
  State<OrdoPage> createState() => _OrdoPageState();
}

class _OrdoPageState extends State<OrdoPage>
    with WidgetsBindingObserver, SelectedDay<OrdoPage> {
  late Future<OrdoServices> _data;
  String? _openedFile;
  OrdoPackage? _importedPackage;

  Future<void> _openPackage() async {
    try {
      final file =
          await (widget.pickPackage?.call() ??
              openFile(
                acceptedTypeGroups: const [
                  XTypeGroup(
                    label: 'Последование .ordo',
                    extensions: ['ordo', 'zip'],
                    mimeTypes: ['application/vnd.ordo+zip', 'application/zip'],
                    uniformTypeIdentifiers: ['public.data'],
                  ),
                ],
              ));
      if (file == null) return;
      if (await file.length() > OrdoPackage.maxBytes) {
        throw const FormatException('Пакет .ordo слишком большой');
      }
      final package = OrdoPackage.decode(await file.readAsBytes());
      if (!mounted) return;
      setState(() {
        _importedPackage = package;
        _openedFile =
            '${file.name}${package.date == null ? '' : ' · ${package.date}'}';
        _data = Future.value(package.reading);
      });
      unawaited(_resolveImported(package));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось прочитать файл .ordo. Проверьте формат пакета.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _resolveImported(OrdoPackage package) async {
    await resolveOrdoScripture(package);
    if (mounted && identical(_importedPackage, package)) {
      setState(() {
        _data = Future.value(package.reading);
      });
    }
  }

  @override
  void loadDay(DateTime day) {
    _openedFile = null;
    _importedPackage = null;
    _data = (widget.loader ?? getOrdoServices)(day);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          Flexible(child: Text('Служба дня')),
          SizedBox(width: 8),
          Chip(label: Text('Бета'), visualDensity: VisualDensity.compact),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Открыть .ordo',
          onPressed: _openPackage,
          icon: const Icon(Icons.file_open_outlined),
        ),
        IconButton(
          tooltip: 'Выбрать дату',
          onPressed: pickDay,
          icon: const Icon(Icons.calendar_month),
        ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Бета-версия. Сборка последования ещё проверяется: '
            'возможны пропуски текстов и ошибки в порядке службы. '
            'Сверяйте последование с богослужебными книгами.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(_openedFile ?? SelectedDay.keyOf(selectedDay)),
        ),
        Expanded(
          child: ColoredBox(
            color: readingBackgroundColor(context),
            child: PinchZoom(
              child: AsyncView<OrdoServices>(
                future: _data,
                message: 'Не удалось открыть службу дня.',
                onRetry: reloadSelectedDay,
                onRefresh: _openedFile != null
                    ? null
                    : () {
                        reloadSelectedDay();
                        return settle(_data);
                      },
                isEmpty: (data) => data.services.isEmpty,
                emptyMessage: 'На эту дату службы не собраны.',
                builder: (context, data) => SingleChildScrollView(
                  key: ValueKey(_openedFile ?? SelectedDay.keyOf(selectedDay)),
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
