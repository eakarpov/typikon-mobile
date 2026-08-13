import 'package:flutter/material.dart';

/// One jump-to entry in a table of contents: a liturgical place (e.g. "По
/// седальнах первой кафизмы") and, nested under it, the individual texts
/// read there when there is more than one.
class TocEntry {
  final String title;
  final GlobalKey anchorKey;
  final List<TocEntry> children;

  TocEntry({
    required this.title,
    required this.anchorKey,
    this.children = const [],
  });
}

Future<void> showTableOfContents(BuildContext context, List<TocEntry> entries) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            children: entries.expand((entry) => _tocTiles(context, entry, 0)).toList(),
          );
        },
      );
    },
  );
}

List<Widget> _tocTiles(BuildContext context, TocEntry entry, int depth) {
  return [
    ListTile(
      dense: depth > 0,
      contentPadding: EdgeInsets.only(left: 16.0 + depth * 16.0, right: 16.0),
      title: Text(
        entry.title,
        style: TextStyle(
          fontFamily: "OldStandard",
          fontWeight: depth == 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () => _jumpTo(context, entry.anchorKey),
    ),
    for (final child in entry.children) ..._tocTiles(context, child, depth + 1),
  ];
}

void _jumpTo(BuildContext context, GlobalKey key) {
  Navigator.pop(context);
  Future.delayed(const Duration(milliseconds: 300), () {
    final targetContext = key.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    }
  });
}
