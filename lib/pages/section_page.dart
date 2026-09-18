import 'package:flutter/material.dart';

import 'package:typikon/pages/menu_entries.dart';

/// Экран-раздел: «Собрание» и «Пособия».
///
/// Заведён ради того, чего строка в ящике меню дать не может, — **пояснения**.
/// «Каноны» и «Песнопения» для того, кто заходит впервые, слова близкие; разница
/// между ними в единице выдачи, и сказать об этом можно только строкой под
/// именем.
///
/// Заодно ящик перестаёт расти от каждого нового раздела: одиннадцать пунктов
/// ушли под два.
class SectionPage extends StatelessWidget {
  final String title;
  final List<MenuEntry> entries;

  const SectionPage(
    context, {
    super.key,
    required this.title,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            title: Text(entry.title),
            subtitle: entry.hint == null ? null : Text(entry.hint!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, entry.route),
          );
        },
      ),
    );
  }
}
