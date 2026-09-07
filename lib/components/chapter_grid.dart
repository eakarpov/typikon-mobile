import 'package:flutter/material.dart';

/// Выбор главы сеткой номеров.
///
/// Сетка, а не список: сто пятьдесят псалмов списком — долгая прокрутка, а
/// сеткой они помещаются в один-два экрана и ищутся так же, как в бумажной книге.
///
/// Оглавление (`showTableOfContents`) здесь не годится, и это не вкусовое: оно
/// устроено вокруг `GlobalKey`-якорей внутри одной страницы, а глава Библии —
/// отдельная страница со своим запросом. Держать ради него всю книгу в памяти
/// значило бы вернуться к тому, от чего веб ушёл, разбив Библию по главам.
Future<int?> showChapterPicker(
  BuildContext context, {
  required String bookName,
  required int chapters,
  required int current,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              bookName,
              style: const TextStyle(fontFamily: "OldStandard", fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: GridView.builder(
              controller: controller,
              padding: const EdgeInsets.all(12.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8.0,
                crossAxisSpacing: 8.0,
              ),
              itemCount: chapters,
              itemBuilder: (context, index) {
                final chapter = index + 1;
                final isCurrent = chapter == current;
                return InkWell(
                  onTap: () => Navigator.pop(context, chapter),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4.0),
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                          : null,
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: Text(
                      "$chapter",
                      style: TextStyle(
                        fontFamily: "OldStandard",
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
