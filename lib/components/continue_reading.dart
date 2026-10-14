import 'package:flutter/material.dart';

import 'package:typikon/store/reading_progress.dart';

/// Секция «Продолжить чтение» на главной: тексты, у которых есть незаконченное
/// место, — имя и полоса прогресса, тап ведёт в текст. Записи без имени
/// (сохранённые до того, как имя стали запоминать) не показываются: подписать
/// их нечем, а идентификатор для человека ни о чём не говорит.
class ContinueReading extends StatelessWidget {
  final List<SavedReading> entries;

  const ContinueReading({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final named = entries.where((entry) => entry.progress.name != null).toList();
    if (named.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Продолжить чтение",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final entry in named)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                entry.progress.name!,
                style: const TextStyle(fontFamily: "OldStandard", color: Colors.red),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: LinearProgressIndicator(value: entry.progress.fraction),
              ),
              onTap: () => Navigator.pushNamed(context, "/reading", arguments: entry.id),
            ),
        ],
      ),
    );
  }
}
