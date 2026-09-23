/// ПИСЬМО: УСТАВОМ ИЛИ ГРАЖДАНКОЙ.
///
/// Церковнославянский в собрании лежит двумя начертаниями. Библия и часть
/// чтений библиотеки набраны уставом — с придыханиями, ятями, омегами, титлами.
/// Весь певческий корпус (`cu_gr`) — гражданкой: тот же язык современными
/// буквами, с ударениями, без ера на конце. Читатель выбирает, каким письмом
/// читать, и тексты другого начертания переводятся.
///
/// **Перевод идёт по правилам, а не по словарю, и потому только в ту меру, в
/// какую правило надёжно.** Из устава в гражданку — почти без потерь: буква
/// заменяется буквой, знаки снимаются. Слова под титлом остаются как есть:
/// «бг҃ъ» не раскрыть без словаря сокращений, а раскрыв наугад, мы напечатали бы
/// слово, которого в книге нет. Из гражданки в устав — только то, что
/// выводится из самого написания: придыхание над начальной гласной, «є» и «ꙗ»
/// в начале слова, «ᲂу» там же, «і» перед гласной, ер после конечной согласной,
/// «ѡ» и «ѿ» предлогами, вария на конечном слоге перед следующим словом. Ять,
/// омега внутри слова, фита и титла — дело словаря: «вера» и «вѣра» правило не
/// различит. Словарь ударений тут не помогает — он отвечает тем написанием,
/// каким спросили («вера» → «ве́ра»), — и показ обязан это оговорить.
library;

/// Что выбрал читатель. Хранится строкой в настройках.
const String scriptAsSource = "source";
const String scriptCivil = "civil";
const String scriptChurch = "church";

/// Каким письмом набран сам текст.
enum TextScript {
  /// Уставом: Библия `cu`, чтения с `csSource`.
  church,

  /// Церковнославянский гражданкой: певческий корпус `cu_gr`.
  civil,

  /// Всё прочее — русский, греческий, латиница, а также тексты библиотеки без
  /// признака языка. Их не переводим никуда: русскую прозу уставом переписывать
  /// нельзя, а узнать, русская ли она, не по чему.
  other,
}

/// Будет ли текст переведён при этой настройке.
bool convertsScript(TextScript source, String setting) =>
    (source == TextScript.church && setting == scriptCivil) ||
    (source == TextScript.civil && setting == scriptChurch);

/// Текст тем письмом, какое выбрал читатель.
String presentScript(String text, TextScript source, String setting) {
  if (source == TextScript.church && setting == scriptCivil) return toCivil(text);
  if (source == TextScript.civil && setting == scriptChurch) return toChurch(text);
  return text;
}

/// Шрифт под письмо. Уставу нужен Monomakh: в OldStandard нет узкого «ᲂ»
/// (U+1C82), и «ᲂу҆» осыпалось бы квадратом. Гражданке — OldStandard.
String presentFont(String font, TextScript source, String setting) {
  if (source == TextScript.church && setting == scriptCivil) return "OldStandard";
  if (source == TextScript.civil && setting == scriptChurch) return "Monomakh";
  return font;
}

// --- Разметка -------------------------------------------------------------------

/// Метки текстов библиотеки: `{k|`, `{pl|опознаватель|` и `{pl|опознаватель}`,
/// `{12}` и закрывающая скобка. Переводится видимое между ними, а сами метки —
/// нет: опознаватель места, переписанный другими буквами, никуда бы не вёл.
final RegExp _markup = RegExp(r"\{k\||\{pl\|[^|}]*\|?|\{\d+\}|\}");

String _outsideMarkup(String text, String Function(String) convert) {
  final buffer = StringBuffer();
  var cursor = 0;
  for (final match in _markup.allMatches(text)) {
    buffer.write(convert(text.substring(cursor, match.start)));
    buffer.write(match.group(0));
    cursor = match.end;
  }
  buffer.write(convert(text.substring(cursor)));
  return buffer.toString();
}

// --- Слова ----------------------------------------------------------------------

/// Надстрочные знаки: ударения, придыхания, титла, покрытие, камора.
bool _isMark(int code) =>
    (code >= 0x0300 && code <= 0x036F) ||
    (code >= 0x0483 && code <= 0x0489) ||
    (code >= 0xA66F && code <= 0xA67D);

/// Буквотитла — надстрочные буквы «гдⷭ҇ь».
bool _isSuperscriptLetter(int code) => code >= 0x2DE0 && code <= 0x2DFF;

bool _isWordChar(int code) {
  if (_isMark(code) || _isSuperscriptLetter(code)) return true;
  if (code == 0x2E2F || code == 0xA67F) return true; // ерок, паерок
  return (code >= 0x0400 && code <= 0x052F) ||
      (code >= 0x1C80 && code <= 0x1C88) ||
      (code >= 0xA640 && code <= 0xA69F);
}

/// Слова и промежутки между ними, по порядку.
List<(String, bool)> _tokens(String text) {
  final tokens = <(String, bool)>[];
  final buffer = StringBuffer();
  bool? inWord;
  for (final rune in text.runes) {
    final isWord = _isWordChar(rune);
    if (inWord != null && isWord != inWord) {
      tokens.add((buffer.toString(), inWord));
      buffer.clear();
    }
    buffer.writeCharCode(rune);
    inWord = isWord;
  }
  if (inWord != null) tokens.add((buffer.toString(), inWord));
  return tokens;
}

/// Буква и знаки над ней.
class _Cluster {
  String base;
  final List<int> marks;

  _Cluster(this.base, [List<int>? marks]) : marks = marks ?? [];

  @override
  String toString() => base + String.fromCharCodes(marks);
}

List<_Cluster> _clusters(String word) {
  final clusters = <_Cluster>[];
  for (final rune in word.runes) {
    if (_isMark(rune) && clusters.isNotEmpty) {
      clusters.last.marks.add(rune);
    } else {
      clusters.add(_Cluster(String.fromCharCode(rune)));
    }
  }
  return clusters;
}

const int _oxia = 0x0301;
const int _varia = 0x0300;
const int _kamora = 0x0311;
const int _psili = 0x0486;

bool _isUpper(String letter) => letter != letter.toLowerCase();

// --- Из устава в гражданку -------------------------------------------------------

const Map<String, String> _toCivilLetters = {
  "ѣ": "е", "Ѣ": "Е",
  "і": "и", "І": "И",
  "ї": "и", "Ї": "И",
  "ѡ": "о", "Ѡ": "О",
  "ѻ": "о", "Ѻ": "О",
  "ꙍ": "о", "Ꙍ": "О",
  "ꙩ": "о", "ꙫ": "о", "ꙭ": "о", "ꙮ": "о",
  "ѽ": "о", "Ѽ": "О",
  "ѿ": "от", "Ѿ": "От",
  "ꙋ": "у", "Ꙋ": "У",
  "ѹ": "у", "Ѹ": "У",
  "ѫ": "у", "Ѫ": "У",
  "ѭ": "ю", "Ѭ": "Ю",
  "ꙗ": "я", "Ꙗ": "Я",
  "ѧ": "я", "Ѧ": "Я",
  "ѥ": "е", "Ѥ": "Е",
  "є": "е", "Є": "Е",
  "ѳ": "ф", "Ѳ": "Ф",
  "ѯ": "кс", "Ѯ": "Кс",
  "ѱ": "пс", "Ѱ": "Пс",
  "ѕ": "з", "Ѕ": "З",
  "ꙁ": "з", "Ꙁ": "З",
  "ꙃ": "з", "Ꙃ": "З",
  "ꙑ": "ы", "Ꙑ": "Ы",
  "ⸯ": "ъ", "ꙿ": "ъ",
};

const String _consonants = "бвгджзклмнпрстфхцчшщБВГДЖЗКЛМНПРСТФХЦЧШЩ";

/// Из устава — в гражданку, как набран певческий корпус.
String toCivil(String text) => _outsideMarkup(text, (plain) {
      final buffer = StringBuffer();
      for (final (token, isWord) in _tokens(plain)) {
        buffer.write(isWord ? _wordToCivil(token) : token);
      }
      return buffer.toString();
    });

String _wordToCivil(String word) {
  // Под титлом — сокращение. Раскрыть его без словаря нельзя, а раскрыв
  // наугад, мы напечатали бы слово, которого в книге нет. Остаётся как есть:
  // знаки его OldStandard рисует.
  if (word.runes.any((code) => code == 0x0483 || code == 0x0487 || _isSuperscriptLetter(code))) {
    return word;
  }

  final clusters = _clusters(word);
  if (clusters.isEmpty) return word;

  // «ᲂу» и «оу» в начале слова — одна буква «у». Внутри слова «оу» не трогаем:
  // «поуча́ти» — это «по» и «учати», а не «пучати».
  if (clusters.length > 1) {
    final first = clusters[0].base;
    final second = clusters[1].base;
    if ((first == "ᲂ" || first == "о" || first == "О") && (second == "у" || second == "ꙋ")) {
      final upper = first == "О";
      clusters[1].base = upper ? "У" : "у";
      clusters[1].marks.insertAll(0, clusters[0].marks);
      clusters.removeAt(0);
    }
  }

  for (var i = 0; i < clusters.length; i++) {
    final cluster = clusters[i];
    final base = cluster.base;

    // Ижица после «а» и «е» читается «в»: «Еѵа», «аѵгустъ».
    if (base == "ѵ" || base == "Ѵ" || base == "ѷ" || base == "Ѷ") {
      final previous = i > 0 ? clusters[i - 1].base.toLowerCase() : "";
      final asV = previous == "а" || previous == "е" || previous == "є";
      cluster.base = asV ? (_isUpper(base) ? "В" : "в") : (_isUpper(base) ? "И" : "и");
    } else if (base == "ᲂ") {
      cluster.base = "о";
    } else {
      cluster.base = _toCivilLetters[base] ?? base;
    }

    // Придыхания снимаются; вария и камора — те же ударения, гражданка пишет
    // их одним знаком.
    final kept = <int>[];
    for (final mark in cluster.marks) {
      if (mark == 0x0485 || mark == _psili) continue;
      if (mark == _varia || mark == _kamora) {
        if (!kept.contains(_oxia)) kept.add(_oxia);
        continue;
      }
      kept.add(mark);
    }
    cluster.marks
      ..clear()
      ..addAll(kept);
  }

  // Ер на конце после согласной гражданка не пишет: «грех», а не «грѣхъ».
  if (clusters.length > 1) {
    final last = clusters.last;
    final beforeLast = clusters[clusters.length - 2].base;
    if ((last.base == "ъ" || last.base == "Ъ") &&
        last.marks.isEmpty &&
        _consonants.contains(beforeLast)) {
      clusters.removeLast();
    }
  }

  return clusters.join();
}

// --- Из гражданки в устав -------------------------------------------------------

const String _vowels = "аеёиоуыэюяіАЕЁИОУЫЭЮЯІ";

/// Из гражданки — в устав, насколько это выводится из самого написания.
String toChurch(String text) => _outsideMarkup(text, (plain) {
      final tokens = _tokens(plain);
      final buffer = StringBuffer();
      for (var i = 0; i < tokens.length; i++) {
        final (token, isWord) = tokens[i];
        if (!isWord) {
          buffer.write(token);
          continue;
        }
        // Вария вместо оксии на конечном слоге — если за словом идёт другое
        // слово, а не знак препинания и не конец строки.
        final beforeWord = i + 2 < tokens.length &&
            tokens[i + 2].$2 &&
            tokens[i + 1].$1.trim().isEmpty;
        buffer.write(_wordToChurch(token, beforeWord: beforeWord));
      }
      return buffer.toString();
    });

String _wordToChurch(String word, {required bool beforeWord}) {
  final clusters = _clusters(word);
  if (clusters.isEmpty || !clusters.any((c) => c.base.runes.any(_isCyrillicLetter))) {
    return word;
  }

  final bare = clusters.map((c) => c.base.toLowerCase()).join();

  // Предлоги пишутся своими буквами.
  if (bare == "от") {
    final upper = _isUpper(clusters.first.base);
    return (upper ? "Ѿ" : "ѿ") + String.fromCharCodes(clusters.expand((c) => c.marks));
  }
  if (bare == "о") {
    clusters.first.base = _isUpper(clusters.first.base) ? "Ѡ" : "ѡ";
  }

  // «і» перед гласной: «Іисусъ», «Марія».
  for (var i = 0; i + 1 < clusters.length; i++) {
    final base = clusters[i].base;
    if ((base == "и" || base == "И") && _vowels.contains(clusters[i + 1].base)) {
      clusters[i].base = base == "И" ? "І" : "і";
    }
  }

  // Ер после конечной согласной: «грехъ», «въ».
  if (_consonants.contains(clusters.last.base)) {
    final allUpper = clusters.length > 1 && clusters.every((c) => _isUpper(c.base));
    clusters.add(_Cluster(allUpper ? "Ъ" : "ъ"));
  }

  // Вария на конечном слоге перед следующим словом.
  if (beforeWord) {
    final lastVowel = clusters.lastIndexWhere((c) => _vowels.contains(c.base));
    if (lastVowel >= 0) {
      final marks = clusters[lastVowel].marks;
      final at = marks.indexOf(_oxia);
      if (at >= 0) marks[at] = _varia;
    }
  }

  // Начальная гласная: своя буква и придыхание.
  final first = clusters.first;
  if (_vowels.contains(first.base) || first.base == "ѡ" || first.base == "Ѡ") {
    final upper = _isUpper(first.base);
    switch (first.base.toLowerCase()) {
      case "е":
        first.base = upper ? "Є" : "є";
      case "я":
        first.base = upper ? "Ꙗ" : "ꙗ";
      case "у":
        // «ᲂу» — узкое «о» с «у»; у прописной узкого «о» нет, пишется «Оу».
        clusters.insert(0, _Cluster(upper ? "О" : "ᲂ"));
        first.base = "у";
    }
    first.marks.insert(0, _psili);
  }

  return clusters.join();
}

bool _isCyrillicLetter(int code) =>
    (code >= 0x0400 && code <= 0x052F) || (code >= 0x1C80 && code <= 0x1C88) || (code >= 0xA640 && code <= 0xA69F);

/// Письмо издания Библии. Уставом набраны только `cu`: `ro_cyr` — румынский
/// кириллицей, а не церковнославянский, и переписывать его нельзя.
TextScript bibleScript(String? language) =>
    language == "cu" ? TextScript.church : TextScript.other;

/// Письмо песнопения. Корпус весь `cu_gr`; у акафистов признака языка в ответе
/// нет вовсе, и они тоже `cu_gr`. Перевод трогает только кириллицу, так что
/// латиница и греческий, окажись они здесь, остались бы как есть.
TextScript chantScript(String? language) {
  if (language == null || language == "cu_gr") return TextScript.civil;
  if (language == "cu") return TextScript.church;
  return TextScript.other;
}
