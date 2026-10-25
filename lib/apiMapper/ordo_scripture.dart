import '../domain/ordo_package.dart';
import '../dto/bible.dart';
import 'bible.dart';

/// Адреса по spec/package.md: bible:ioanna.19.6-11,19.13-20.
/// Книги и каноническая нумерация принадлежат существующему API Библии.
Future<OrdoPackage> resolveOrdoScripture(
  OrdoPackage package, {
  Future<BibleChapter> Function(String, int)? loadChapter,
}) async {
  final chapters = <String, Future<BibleChapter>>{};
  await package.resolveScripture((ref) async {
    final value = ref.substring('bible:'.length);
    final firstDot = value.indexOf('.');
    if (firstDot < 1) return null;
    final book = value.substring(0, firstDot);
    final pieces = <String>[];
    for (final part in value.substring(firstDot + 1).split(',')) {
      final match = RegExp(r'^(\d+)\.(\d+)(?:-(\d+))?$').firstMatch(part);
      if (match == null) return null;
      final chapter = int.parse(match[1]!);
      final from = int.parse(match[2]!);
      final to = int.parse(match[3] ?? match[2]!);
      if (from > to) return null;
      final data = await chapters.putIfAbsent(
        '$book:$chapter',
        () => (loadChapter ?? getBibleChapter)(book, chapter),
      );
      final verses = data
          .versesFor(0)
          .where((v) => v.verse >= from && v.verse <= to)
          .toList();
      // Не выдаём частичное зачало за полное.
      if (verses.map((v) => v.verse).toSet().length != to - from + 1) {
        return null;
      }
      pieces.add(verses.map((v) => v.content).join('\n'));
    }
    return pieces.join(' … ');
  });
  return package;
}
