import 'package:flutter/material.dart';
import '../apiMapper/saints.dart';
import '../dto/saint.dart';
import '../dto/dneslov/images.dart';
import 'api_error_view.dart';

class SaintIcons extends StatefulWidget {
  const SaintIcons({
    super.key,
    required this.saint,
    this.loader = getSaintIcons,
  });
  final SaintDossier saint;
  final Future<DneslovImageListD> Function(SaintDossier) loader;
  @override
  State<SaintIcons> createState() => _SaintIconsState();
}

class _SaintIconsState extends State<SaintIcons> {
  late Future<DneslovImageListD> _images;
  void _load() {
    _images = widget.loader(widget.saint);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SaintIcons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saint != widget.saint || oldWidget.loader != widget.loader) {
      _load();
    }
  }

  Widget _image(String url) => Image.network(
    url,
    fit: BoxFit.contain,
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : const Center(child: CircularProgressIndicator()),
    errorBuilder: (context, error, stack) =>
        const Center(child: Text('Не удалось загрузить изображение.')),
  );

  void _open(DneslovImageDItem item, String title) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: Center(child: _image(item.url)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DneslovImageListD>(
    future: _images,
    initialData: widget.saint.images.isEmpty
        ? null
        : DneslovImageListD(list: widget.saint.images),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ApiErrorView(
          error: snapshot.error,
          message: 'Не удалось загрузить иконы.',
          onRetry: () => setState(_load),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final items = snapshot.data!.list;
      if (items.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Для этой записи пока нет изображений.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final title = item.title.isEmpty
              ? 'Изображение ${index + 1}'
              : item.title;
          return Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  key: ValueKey('saint-icon-${item.uid}'),
                  onTap: () => _open(item, title),
                  child: Semantics(
                    button: true,
                    label: 'Открыть: $title',
                    child: SizedBox(height: 340, child: _image(item.thumb_url)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title),
                      if (item.description.isNotEmpty &&
                          item.description.trim() != title.trim())
                        Text(
                          item.description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
