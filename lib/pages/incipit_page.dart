import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../apiMapper/singing.dart';
import '../components/paged_list.dart';
import '../dto/incipit.dart';
import '../store/models/models.dart';
import '../utils/singing_labels.dart';

/// Карточка зачина: где это песнопение встречается и что ему соответствует.
///
/// Список указателя отвечает «такой зачин есть и встречается столько-то раз».
/// Карточка отвечает на следующий вопрос — «где именно», — и это то, ради чего
/// указатель и нужен: узнать песнопение по первым словам и найти его место.
class IncipitPage extends StatefulWidget {
  const IncipitPage(
    context, {
    super.key,
    required this.language,
    required this.incipit,
  });

  final String language;
  final String incipit;

  @override
  State<IncipitPage> createState() => _IncipitPageState();
}

class _IncipitPageState extends State<IncipitPage> {
  late Future<IncipitDetail> detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    detail = getIncipit(widget.language, widget.incipit);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize =
        StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Зачин", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: FutureBuilder<IncipitDetail>(
        future: detail,
        builder: (context, future) {
          if (future.hasError) {
            return searchErrorView(
              context,
              future.error!,
              "Не удалось открыть зачин.",
              () => setState(_load),
            );
          }
          if (!future.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _body(context, future.data!, fontSize);
        },
      ),
    );
  }

  Widget _body(BuildContext context, IncipitDetail data, double fontSize) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
      children: [
        Text(
          data.text,
          style: TextStyle(fontFamily: "Monomakh", fontSize: fontSize),
        ),
        const SizedBox(height: 8.0),
        Text(
          "${languageLabel(data.language)} · вхождений: ${data.uses}",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (data.borrowed)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              // Текст не свой — подтянут по ссылке. Сказать об этом надо: иначе
              // читатель решит, что так напечатано именно здесь.
              "Текст показан по ссылке из Ирмология или соседнего канона: "
              "в самой книге на этом месте стоит только зачин.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const Divider(height: 32.0),
        _witnesses(context, data),
        _correspondences(context, data, fontSize),
      ],
    );
  }

  Widget _witnesses(BuildContext context, IncipitDetail data) {
    if (data.witnesses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, "Где встречается"),
        ...data.witnesses.map((witness) {
          final address = witnessAddress(witness);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              address.isEmpty ? "без адреса" : address.join(" · "),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }),
      ],
    );
  }

  Widget _correspondences(BuildContext context, IncipitDetail data, double fontSize) {
    if (!data.hasCorrespondences) {
      return Padding(
        padding: const EdgeInsets.only(top: 24.0),
        child: Text(
          // Пустота здесь значит «связь не построена», а не «соответствия нет».
          // Славянское связано с другими языками примерно на девять процентов, и
          // прочесть пустоту как утверждение было бы прямой ошибкой.
          "Соответствий на другие языки для этого зачина не найдено. "
          "Это не значит, что их нет: связаны пока не все песнопения.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16.0),
        if (data.declared.isNotEmpty) ...[
          _heading(context, "То же в других изданиях"),
          ...data.declared.map((link) => _link(context, link, fontSize)),
        ],
        if (data.supposed.isNotEmpty) ...[
          _heading(context, "Похоже, то же самое"),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              // Догадка названа догадкой. Схлопнуть её с заявленным значило бы
              // переложить свою неуверенность на читателя молча.
              "Связано по совпавшему месту службы, а не по указанию издателя — "
              "здесь возможна ошибка.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ...data.supposed.map((link) => _link(context, link, fontSize)),
        ],
      ],
    );
  }

  Widget _link(BuildContext context, IncipitCorrespondence link, double fontSize) {
    final evidence = link.evidence;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            link.text,
            style: TextStyle(fontFamily: "OldStandard", fontSize: fontSize * 0.95),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              [languageLabel(link.language), correspondenceLabel(link)]
                  .where((part) => part.isNotEmpty)
                  .join(" · "),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (evidence != null)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(evidence, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: "OldStandard",
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}
