import 'package:flutter/material.dart';

import '../dto/pomyannik.dart';
import '../utils/pomyannik_labels.dart';

/// САМА ЗАПИСКА — тот лист, что подают.
///
/// Один вид на обе стороны: и тому, кто собирает, и тому, кто читает,
/// показывается ровно одно и то же. Две почти одинаковые вёрстки завели бы две
/// правды о том, как записка выглядит, и разошлись бы они на первой же правке.
///
/// **Шрифт — Monomakh, и это проверено по таблице кодировки, а не на глаз.**
/// В OldStandard нет ни креста ☦ (U+2626), ни узкого `ᲂ` (U+1C82) из
/// «ᲂу҆поко́енїи»: набранный им заголовок осыпался бы квадратами. В Monomakh есть
/// и то и другое.
///
/// **Крест снимается галочкой, и это не прихоть вёрстки.** Записку надписывают
/// крестом — так она и выглядит на бумаге. Но лист с крестом уже не выбросишь:
/// его сжигают. Кто печатает записку дома и не хочет этой заботы, вправе крест
/// не ставить, и решать это за него мы не станем.
///
/// **Чин строчными, имя с прописной.** Словарь лексем хранит леммы строчными, и
/// склонение выдаёт их такими же; в записке же имя пишут с прописной — это имя
/// человека, а не слово из словаря.
class NoteSheetView extends StatelessWidget {
  const NoteSheetView({
    super.key,
    required this.sheet,
    required this.vocabulary,
    this.cross = true,
  });

  final NoteSheet sheet;
  final Vocabulary vocabulary;
  final bool cross;

  static const String _crossGlyph = "☦";
  static const String _font = "Monomakh";

  @override
  Widget build(BuildContext context) {
    final living = sheet.livingNames.toList();
    final departed = sheet.departedNames.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cross)
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              _crossGlyph,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: _font, fontSize: 24.0),
            ),
          ),
        if (living.isNotEmpty)
          _Group(title: "ѡ҆ здра́вїи", names: living, vocabulary: vocabulary),
        if (departed.isNotEmpty)
          _Group(title: "ѡ҆ ᲂу҆поко́енїи", names: departed, vocabulary: vocabulary),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.names, required this.vocabulary});

  final String title;
  final List<NoteName> names;
  final Vocabulary vocabulary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: NoteSheetView._font,
              fontSize: 18.0,
            ),
          ),
          const SizedBox(height: 6.0),
          ...names.map((name) => _Name(name: name, vocabulary: vocabulary)),
        ],
      ),
    );
  }
}

class _Name extends StatelessWidget {
  const _Name({required this.name, required this.vocabulary});

  final NoteName name;
  final Vocabulary vocabulary;

  @override
  Widget build(BuildContext context) {
    // Помета церковнославянским письмом, если она книгой подтверждена. `null`
    // значит «не знаем» — и тогда ставим гражданку, а сказать об этом обязана
    // строка под листом.
    final church = rankChurchGenitive(vocabulary, name);
    final rank = church ?? rankGenitive(vocabulary, name);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        rank.isEmpty ? capitalize(name.text) : "$rank ${capitalize(name.text)}",
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: NoteSheetView._font, fontSize: 18.0),
      ),
    );
  }
}

/// Оговорки под листом: где склонение наше и где помета стоит гражданкой.
///
/// Без них выйдет худшее, что здесь возможно: человек примет наш именительный
/// падеж за проверенный родительный и отдаст записку с ошибкой, которой сам бы
/// не сделал.
class NoteSheetCaveats extends StatelessWidget {
  const NoteSheetCaveats({super.key, required this.sheet, required this.vocabulary});

  final NoteSheet sheet;
  final Vocabulary vocabulary;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;

    final undeclined = sheet.undeclined.map((n) => n.name).toList();
    final civil = sheet.names
        .where((n) => (n.rank ?? "").isNotEmpty && rankChurchGenitive(vocabulary, n) == null)
        .map((n) => rankGenitive(vocabulary, n))
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList();

    if (undeclined.isEmpty && civil.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (undeclined.isNotEmpty)
            Text(
              "Этих имён нет в словаре, и падеж у них остался прежним — "
              "именительным: ${undeclined.join(", ")}.",
              style: small,
            ),
          if (civil.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: undeclined.isEmpty ? 0.0 : 6.0),
              child: Text(
                "Церковнославянского написания этих помет в наших книгах не нашлось, "
                "и они стоят гражданкой: ${civil.join(", ")}.",
                style: small,
              ),
            ),
        ],
      ),
    );
  }
}
