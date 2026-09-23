import 'package:flutter/material.dart';

import '../apiMapper/reference.dart';
import '../dto/reference.dart';
import '../utils/lexeme_labels.dart';
import '../utils/selected_word.dart';
import 'api_error_view.dart';

/// Шторка «ударение и разбор» для одного слова из текста.
///
/// Толкований в словаре собрания нет — только формы, — поэтому шторка
/// отвечает на два вопроса, на которые ответ есть: как слово прочесть и что это
/// за форма. Значение слова ищется по начальной форме, и дорога к ней — статья
/// словаря.
void showWordSheet(BuildContext context, String word) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => WordSheet(word: word),
  );
}

class WordSheet extends StatefulWidget {
  final String word;

  const WordSheet({super.key, required this.word});

  @override
  State<WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<WordSheet> {
  late Future<WordAccents> _accents;

  /// Статьи словаря по начальной форме. Будущее заводится один раз на форму,
  /// а не в `build`: иначе каждая перерисовка шторки уходила бы в поиск заново.
  final Map<String, Future<String?>> _lexemeIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _accents = getWordAccents(widget.word);
  }

  /// Статья не нашлась или поиск не удался — одно и то же для шторки: ссылки
  /// нет. Отказ поиска не повод прятать ударение, ради которого её открыли.
  Future<String?> _lexemeId(String spelling) => _lexemeIds.putIfAbsent(
        spelling,
        () => findLexemeId(spelling).catchError((Object _) => null),
      );

  void _openLexeme(String id) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pushNamed("/dictionary", arguments: id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.word, style: const TextStyle(fontFamily: "Monomakh", fontSize: 26.0)),
              const SizedBox(height: 12.0),
              FutureBuilder<WordAccents>(
                future: _accents,
                builder: (context, future) {
                  if (future.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(failureMessage(future.error, "ударение не загрузилось")),
                        TextButton(
                          onPressed: () => setState(_load),
                          child: const Text("Повторить"),
                        ),
                      ],
                    );
                  }
                  if (future.connectionState != ConnectionState.done || !future.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _answer(context, theme, future.data!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answer(BuildContext context, ThemeData theme, WordAccents accents) {
    final caption = theme.textTheme.bodySmall;

    if (!accents.known) {
      return Text(hasTitlo(widget.word)
          ? "Слово под титлом — сокращение, а сокращений словарь не разбирает."
          : "Этого слова нет ни в словаре, ни среди текстов, где стоят ударения.");
    }

    final stresses = accents.stresses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(theme, "Ударение"),
        if (stresses.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              "Ставят по-разному. Какое верно здесь, решает смысл места"
              "${accents.lexicon.isEmpty ? "" : " — разбор ниже"}.",
              style: caption,
            ),
          ),
        for (final stress in stresses)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(stress.spelling,
                    style: const TextStyle(fontFamily: "Monomakh", fontSize: 22.0)),
                const SizedBox(width: 12.0),
                Expanded(child: Text(_usageLine(stress), style: caption)),
              ],
            ),
          ),
        const SizedBox(height: 12.0),
        _heading(theme, "Разбор"),
        if (accents.lexicon.isNotEmpty)
          for (final group in _byLemma(accents.lexicon)) _readingTile(theme, group)
        else
          _unparsed(theme),
      ],
    );
  }

  Widget _heading(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(text, style: theme.textTheme.titleSmall),
      );

  /// Где и как часто стоит это ударение. Чтения и песнопения — порознь: у
  /// «спасе» они расходятся, и общая доля спрятала бы именно это.
  String _usageLine(StressVariant stress) {
    String percent(double share) => "${(share * 100).round()} %";
    final parts = <String>[
      if (stress.readingsShare != null) "в чтениях ${percent(stress.readingsShare!)}",
      if (stress.chantsShare != null) "в песнопениях ${percent(stress.chantsShare!)}",
    ];
    if (parts.isEmpty) return stress.inLexicon ? "по словарю" : "";
    return parts.join(" · ");
  }

  /// Формы одного написания от одной начальной формы — одной строкой: «ихже»
  /// сервер отдаёт тремя разборами, и три строки подряд с одинаковым словом
  /// читались бы как три разных слова.
  List<List<WordReading>> _byLemma(List<WordReading> lexicon) {
    final groups = <String, List<WordReading>>{};
    for (final reading in lexicon) {
      groups.putIfAbsent("${reading.lexeme}\n${reading.spelling}", () => []).add(reading);
    }
    return groups.values.toList();
  }

  Widget _readingTile(ThemeData theme, List<WordReading> group) {
    final first = group.first;
    final parses = group.expand((reading) => reading.parses).map(formParseLabel).toList();
    return FutureBuilder<String?>(
      future: _lexemeId(first.lexeme),
      builder: (context, lookup) {
        final id = lookup.data;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(first.spelling,
              style: const TextStyle(fontFamily: "Monomakh", fontSize: 20.0)),
          subtitle: Text.rich(TextSpan(children: [
            const TextSpan(text: "от "),
            TextSpan(text: first.lexeme, style: const TextStyle(fontFamily: "Monomakh")),
            if (parses.isNotEmpty) TextSpan(text: ": ${parses.join("; или ")}"),
          ])),
          trailing: id == null ? null : const Icon(Icons.chevron_right),
          onTap: id == null ? null : () => _openLexeme(id),
        );
      },
    );
  }

  /// Под знаком слово в текстах есть, а в словаре разбора нет: так бывает у
  /// имён — «Христосъ» словарь пишет «хрісто́съ». Статью тогда ищем по самому
  /// слову: у начальной формы она найдётся.
  Widget _unparsed(ThemeData theme) {
    return FutureBuilder<String?>(
      future: _lexemeId(widget.word),
      builder: (context, lookup) {
        final id = lookup.data;
        if (id == null) {
          return Text(
            lookup.connectionState == ConnectionState.done
                ? "Этой формы в словаре нет."
                : "Ищем в словаре…",
            style: theme.textTheme.bodySmall,
          );
        }
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Статья в словаре"),
          subtitle: const Text("Разбора этой формы нет, но слово в словаре есть."),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openLexeme(id),
        );
      },
    );
  }
}
