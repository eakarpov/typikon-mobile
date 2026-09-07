import '../dto/bible.dart';

/// Разделы оглавления Библии.
///
/// Порядок разделов и порядок книг внутри них берётся из ответа сервера, а не
/// задаётся здесь: канон приходит в порядке Елизаветинской Библии, а разделы в
/// нём — сплошные отрезки этого порядка. Поэтому группировка сводится к проходу
/// по списку с началом новой группы там, где сменился признак. Свой порядок
/// разделов был бы второй копией того же знания, и разошлась бы она молча.
///
/// Имена разделов сервер не отдаёт — только идентификаторы, — так что имена наши.
const Map<String, String> bibleSectionLabels = {
  "pentateuch": "Пятикнижие",
  "historical": "Исторические книги",
  "teaching": "Учительные книги",
  "prophetic": "Пророческие книги",
  "lateHistorical": "Маккавейские книги и Ездры",
  "gospel": "Евангелие",
  "apostle": "Апостол",
  "revelation": "Откровение",
  "appendix": "Вне славянского канона",
};

/// Имя раздела. Незнакомый идентификатор отдаём как есть, а не прячем и не
/// подменяем «прочим»: заведи веб новый раздел — и книги останутся видны, просто
/// под непереведённым именем.
String bibleSectionLabel(String id) => bibleSectionLabels[id] ?? id;

class BibleSectionGroup {
  final String id;
  final String label;
  final List<BibleBook> books;

  const BibleSectionGroup({
    required this.id,
    required this.label,
    required this.books,
  });
}

/// Книги, разбитые на разделы порядком их появления.
List<BibleSectionGroup> groupBySection(List<BibleBook> books) {
  final groups = <BibleSectionGroup>[];

  for (final book in books) {
    if (groups.isEmpty || groups.last.id != book.section) {
      groups.add(BibleSectionGroup(
        id: book.section,
        label: bibleSectionLabel(book.section),
        books: [book],
      ));
      continue;
    }
    groups.last.books.add(book);
  }

  return groups;
}
