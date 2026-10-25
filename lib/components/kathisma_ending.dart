import 'package:flutter/material.dart';

import '../apiMapper/posledovanie.dart';
import '../dto/posledovanie.dart';
import '../pages/posledovanie_page.dart' show PosledovanieRowView;
import 'api_error_view.dart';

/// Неизменяемые тропари и молитва именно этой кафизмы — из корпуса портала.
/// Загрузка открытая и кэшируется независимо от личного помянника.
class KathismaEnding extends StatefulWidget {
  final int number;
  final Future<Posledovanie> Function(int)? loader;
  const KathismaEnding({super.key, required this.number, this.loader});

  @override
  State<KathismaEnding> createState() => _KathismaEndingState();
}

class _KathismaEndingState extends State<KathismaEnding> {
  late Future<Posledovanie> _future;

  void _load() {
    _future =
        widget.loader?.call(widget.number) ??
        getPosledovanie('psaltir-kafizma-${widget.number}');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant KathismaEnding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.number != widget.number || oldWidget.loader != widget.loader) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Posledovanie>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return errorViewFor(
          context,
          snapshot.error,
          'Не удалось загрузить тропари и молитву по ${widget.number}-й кафизме.',
          () => setState(_load),
        );
      }
      final data = snapshot.data;
      if (data == null) {
        return const Text('Загружаются тропари и молитва кафизмы…');
      }
      if (data.rows.isEmpty) {
        return Text('В корпусе пока нет окончания ${widget.number}-й кафизмы.');
      }
      String? previousLabel;
      final rows = <Widget>[];
      for (final row in data.rows) {
        rows.add(
          PosledovanieRowView(row: row, showLabel: row.label != previousLabel),
        );
        previousLabel = row.label;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    },
  );
}
