import 'package:flutter/material.dart';
import '../apiMapper/reading.dart';
import '../apiMapper/singing.dart';
import '../components/async_view.dart';
import '../components/fusion_text.dart';
import '../components/pinch_zoom.dart';
import '../components/selection_menu.dart';
import '../dto/text.dart';
import '../dto/corpus.dart';
import '../utils/accents.dart';
import '../utils/reading_style.dart';
import 'canon_page.dart';

class RuleOfficeTarget {
  final String textId;
  final String title;
  final String? canonId;
  final int? tone;
  final bool needsCanon;
  const RuleOfficeTarget({
    required this.textId,
    required this.title,
    this.canonId,
    this.tone,
    this.needsCanon = false,
  });
}

/// Место канона берётся из рубрики книги, а не из приблизительной позиции.
(String, String)? splitOfficeAtCanon(String text) {
  for (final match in RegExp(r'\{k\|[^}]*\}', dotAll: true).allMatches(text)) {
    if (RegExp(
      r'(чтем|глаголем)\s+канон',
    ).hasMatch(stripAccents(match[0]!).toLowerCase())) {
      return (text.substring(0, match.start), text.substring(match.end));
    }
  }
  return null;
}

class RuleOfficeData {
  final Reading reading;
  final CanonDetail? canon;
  const RuleOfficeData(this.reading, this.canon);
}

class RuleOfficePage extends StatefulWidget {
  const RuleOfficePage({super.key, required this.target, this.loader});
  final RuleOfficeTarget target;
  final Future<RuleOfficeData> Function()? loader;
  @override
  State<RuleOfficePage> createState() => _RuleOfficePageState();
}

class _RuleOfficePageState extends State<RuleOfficePage> {
  late Future<RuleOfficeData> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = widget.loader?.call() ?? _fetch();
  }

  Future<RuleOfficeData> _fetch() async {
    final target = widget.target;
    final canon = target.canonId == null
        ? Future<CanonDetail?>.value()
        : getCanon(
            target.canonId!,
          ).then<CanonDetail?>((c) => c).catchError((Object _) => null);
    final reading = await getText(target.textId);
    return RuleOfficeData(reading, await canon);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.target.title)),
    body: PinchZoom(
      child: ColoredBox(
        color: readingBackgroundColor(context),
        child: AsyncView<RuleOfficeData>(
          future: _data,
          message: 'Не удалось открыть последование.',
          onRetry: () => setState(_load),
          builder: (context, data) {
            final split = widget.target.needsCanon
                ? splitOfficeAtCanon(data.reading.content)
                : null;
            Widget text(String content) => FusionTextWidgets(
              text: content,
              footnotes: data.reading.footnotes,
              fontFamily: data.reading.csSource ? 'Monomakh' : 'OldStandard',
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectionMenu.wordsOnly(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (split == null)
                      text(data.reading.content)
                    else
                      text(split.$1),
                    if (widget.target.needsCanon) ...[
                      if (split == null)
                        const Text('В тексте не найдено место канона.')
                      else if (data.canon == null) ...[
                        const Text(
                          'Не удалось загрузить канон для этого дня и гласа.',
                        ),
                        TextButton(
                          onPressed: widget.target.canonId == null
                              ? () => Navigator.pop(context)
                              : () => setState(_load),
                          child: Text(
                            widget.target.canonId == null
                                ? 'Вернуться к правилу'
                                : 'Повторить',
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Канон${widget.target.tone == null ? '' : ' · глас ${widget.target.tone}'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        EmbeddedCanon(data.canon!),
                      ],
                    ],
                    if (split != null) text(split.$2),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
