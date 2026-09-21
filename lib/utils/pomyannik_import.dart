import 'package:typikon/dto/pomyannik.dart';

/// Разбор списка имён, принесённого файлом или вставкой.
///
/// Помянник заводят не по одному имени: у человека уже есть список — в тетради,
/// в заметках, в переписке, — и переписывать его в приложение по строчке значит
/// не завести помянник вовсе. Разбор и нужен, чтобы этот список перенести.
///
/// **Разбор ничего не записывает.** Он возвращает то, что ПОНЯЛ, вместе с
/// исходной строкой, и показывается это человеку до записи. Догадка, которую
/// видно и можно поправить, — не то же, что догадка, записанная молча.
class ImportedName {
  /// Строка, как она стояла в списке. Нужна, чтобы человек узнал своё.
  final String raw;

  /// Имя, каким его запишут.
  final String name;

  /// Ключ чина из словаря сервера; `null` — не нашли или не уверены.
  final String? rank;

  /// Родство в скобках: «Анна (мама)». В записку не идёт, а хозяину помогает
  /// не спутать двух Николаев.
  final String? relation;

  const ImportedName({
    required this.raw,
    required this.name,
    this.rank,
    this.relation,
  });

  Map<String, dynamic> toInput(String kind) => {
        "name": name,
        "kind": kind,
        if (rank != null) "rank": rank,
        if (relation != null) "relation": relation,
      };

  ImportedName copyWith({String? name, Object? rank = _keep, Object? relation = _keep}) =>
      ImportedName(
        raw: raw,
        name: name ?? this.name,
        rank: rank == _keep ? this.rank : rank as String?,
        relation: relation == _keep ? this.relation : relation as String?,
      );
}

const Object _keep = Object();

/// Что вышло из разбора.
class ImportResult {
  final List<ImportedName> names;

  /// Строки, которые не стали именами: заголовки столбцов и повторы. Считаются
  /// и показываются числом — молчаливая пропажа строки из списка родни хуже
  /// лишнего вопроса.
  final List<String> headers;
  final List<String> duplicates;

  const ImportResult({
    this.names = const [],
    this.headers = const [],
    this.duplicates = const [],
  });
}

/// Строки, которыми разграфлён бумажный помянник. Именами они не становятся.
final RegExp _header = RegExp(
  r"^(о\s+здрав|о\s+упокое|за\s+здрав|за\s+упокой|здравие|упокоение|живы|усопш|поминов|помянник)",
  caseSensitive: false,
);

/// Нумерация и маркеры в начале строки: «1.», «1)», «—», «•».
final RegExp _bullet = RegExp(r"^\s*(?:\d+\s*[.)]|[-–—•*·])\s*");

/// Родство в скобках на конце строки.
final RegExp _trailingParens = RegExp(r"\s*\(([^()]{1,40})\)\s*$");

/// Разбирает список.
///
/// [kind] нужен не для того, чтобы его угадывать, — столбец выбран вкладкой, —
/// а чтобы не поставить чин, которого в этом столбце не бывает: «убиенного» о
/// живом или «болящего» об усопшем.
ImportResult parseNameList(
  String text, {
  required List<RankInfo> ranks,
  required String kind,
}) {
  final names = <ImportedName>[];
  final headers = <String>[];
  final duplicates = <String>[];
  final seen = <String>{};

  for (final line in text.split("\n")) {
    final raw = line.trim();
    if (raw.isEmpty) continue;

    final cleaned = raw.replaceFirst(_bullet, "").trim();
    if (cleaned.isEmpty) continue;

    if (_header.hasMatch(cleaned)) {
      headers.add(raw);
      continue;
    }

    final parsed = _parseLine(raw, cleaned, ranks, kind);
    if (parsed == null) continue;

    final key = "${parsed.rank ?? ''}|${parsed.name.toLowerCase()}";
    if (!seen.add(key)) {
      duplicates.add(raw);
      continue;
    }
    names.add(parsed);
  }

  return ImportResult(names: names, headers: headers, duplicates: duplicates);
}

ImportedName? _parseLine(String raw, String cleaned, List<RankInfo> ranks, String kind) {
  var rest = cleaned;

  String? relation;
  final parens = _trailingParens.firstMatch(rest);
  if (parens != null) {
    relation = parens.group(1)!.trim();
    rest = rest.substring(0, parens.start).trim();
  }

  final rank = _takeRank(rest, ranks, kind);
  if (rank != null) {
    rest = rank.rest;
  }

  // Точки и запятые на конце — след списка, а не часть имени.
  rest = rest.replaceFirst(RegExp(r"[\s,.;]+$"), "").trim();
  if (rest.isEmpty) return null;

  return ImportedName(
    raw: raw,
    name: rest,
    rank: rank?.key,
    relation: (relation ?? "").isEmpty ? null : relation,
  );
}

/// Обиходные сокращения, которые началом слова не разрешаются.
///
/// «Прот.» подходит и протоиерею, и протодиакону, «иер.» — и иерею, и
/// иеромонаху, «архи.» — и архиерею, и архимандриту. В церковном обиходе за
/// каждым из них закреплено одно чтение, и здесь записано именно оно: правило
/// по началу слова его не выведет, а отказывать в самом частом сокращении из-за
/// того, что где-то рядом есть похожее, — значит не разобрать половину списков.
///
/// Всё прочее по-прежнему сверяется началом слова: таблица не заменяет правило,
/// а разрешает то, чего правило разрешить не может.
const Map<String, String> _conventional = {
  "прот": "protoierey",
  "протод": "protodiakon",
  "иер": "ierey",
  "иером": "ieromonah",
  "диак": "diakon",
  "архим": "arhimandrit",
  "архиер": "arhierey",
  "игум": "igumen",
  "схим": "shimonah",
};

class _TakenRank {
  final String key;
  final String rest;

  const _TakenRank(this.key, this.rest);
}

/// Отделяет помету от имени.
///
/// Разбираются три написания, потому что все три встречаются в живых списках:
/// полное («протоиерея Иоанна»), именительное («протоиерей Иоанн») и сокращение
/// с точкой («прот. Иоанна»). Сокращение сверяется началом слова, а не таблицей:
/// таблица всё равно не угадала бы, кто как сокращает.
///
/// **Неоднозначное не берётся.** «и.» подходит и иерею, и игумену, и иеромонаху,
/// и иноку; поставить любого наугад — значит приписать человеку сан, которого у
/// него нет. Такая строка остаётся именем целиком, и это видно на разборе.
_TakenRank? _takeRank(String line, List<RankInfo> ranks, String kind) {
  final space = line.indexOf(RegExp(r"\s"));
  if (space <= 0) return null;

  final head = line.substring(0, space);
  final rest = line.substring(space + 1).trim();
  if (rest.isEmpty) return null;

  final suitable = ranks.where((rank) => rank.suits(kind));
  final headLower = _fold(head);

  // Слово целиком — в любой из известных форм.
  for (final rank in suitable) {
    for (final form in _formsOf(rank)) {
      if (_fold(form) == headLower) return _TakenRank(rank.key, rest);
    }
  }

  // Сокращение: «прот.», «мл.», «мон.».
  if (!head.endsWith(".")) return null;
  final stem = headLower.substring(0, headLower.length - 1);
  if (stem.length < 2) return null;

  final conventional = _conventional[stem];
  if (conventional != null) {
    final fits = suitable.any((rank) => rank.key == conventional);
    return fits ? _TakenRank(conventional, rest) : null;
  }

  final matched = <String>{};
  for (final rank in suitable) {
    for (final form in _formsOf(rank)) {
      if (_fold(form).startsWith(stem)) matched.add(rank.key);
    }
  }
  if (matched.length != 1) return null;

  return _TakenRank(matched.single, rest);
}

Iterable<String> _formsOf(RankInfo rank) sync* {
  yield rank.masculine.label;
  yield rank.masculine.genitive;
  final feminine = rank.feminine;
  if (feminine != null) {
    yield feminine.label;
    yield feminine.genitive;
  }
}

/// «Ё» и «е» в списках пишут как придётся, и различать их тут не за что.
String _fold(String value) => value.toLowerCase().replaceAll("ё", "е").trim();
