import '../dto/pomyannik.dart';

// Подписи помянника — русские слова, а не орфография книги, и потому живут
// здесь, а не приходят ручкой. Чины и виды поминовения, наоборот, приходят с
// сервера (`getVocabulary`): у них есть церковнославянские начертания, а с ними
// и `null`, значащий «книгой не подтверждено». Списывать такое на клиент нельзя.
//
// Отдельно от правил счёта: те держит сервер и проверяет своим тестом, и
// меняться они не должны от того, что здесь переписали слово.

const List<String> _months = [
  "", "января", "февраля", "марта", "апреля", "мая", "июня",
  "июля", "августа", "сентября", "октября", "ноября", "декабря",
];

// Именительный падеж: день стоит в перечне сам по себе — «11 сентября,
// пятница», — а не после предлога.
const List<String> _weekdays = [
  "понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье",
];

final RegExp _isoDate = RegExp(r"^(\d{4})-(\d{2})-(\d{2})$");

/// «12 марта 2019». Год опускается, когда он и так понятен из соседства.
String humanDate(String? iso, {bool withYear = true}) {
  final match = _isoDate.firstMatch(iso ?? "");
  if (match == null) return "";

  final day = int.parse(match.group(3)!);
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return "";

  return "$day ${_months[month]}${withYear ? " ${match.group(1)}" : ""}";
}

String weekdayOf(String? iso) {
  final date = DateTime.tryParse(iso ?? "");
  return date == null ? "" : _weekdays[date.weekday - 1];
}

const Map<String, String> _events = {
  "nameday": "именины",
  "birthday": "день рождения",
  "anniversary": "годовщина преставления",
  "third": "третий день",
  "ninth": "девятый день",
  // Не «сороковой день»: сорокоуст считается со дня заказа, а сороковой день —
  // со дня преставления, и заказанный на девятый день сорокоуст кончится на
  // сорок восьмой. Одно слово на два разных дня было бы прямой неправдой.
  "fortieth": "сороковой день",
  "sorokoust-end": "оканчивается сорокоуст",
  "memorial-day": "поминовение усопших",
};

/// Незнакомый род события показывается как есть, а не прячется: заведут на
/// сервере новый — читатель увидит его непереведённым, но увидит.
String eventLabel(String kind) => _events[kind] ?? kind;

/// «через 3 дня», «сегодня», «завтра» — так до дня понятнее, чем числом.
String inDays(int days) {
  if (days <= 0) return "сегодня";
  if (days == 1) return "завтра";
  if (days == 2) return "послезавтра";

  final teen = days % 100;
  final last = days % 10;
  final word = teen >= 11 && teen <= 14
      ? "дней"
      : last == 1
          ? "день"
          : (last >= 2 && last <= 4 ? "дня" : "дней");

  return "через $days $word";
}

String years(int count) {
  final teen = count % 100;
  final last = count % 10;
  if (teen >= 11 && teen <= 14) return "$count лет";
  if (last == 1) return "$count год";
  if (last >= 2 && last <= 4) return "$count года";
  return "$count лет";
}

/// Сколько дней от одной даты до другой. Обе — «ГГГГ-ММ-ДД».
int? daysBetween(String from, String to) {
  final a = DateTime.tryParse(from);
  final b = DateTime.tryParse(to);
  if (a == null || b == null) return null;
  return b.difference(a).inDays;
}

/// Сегодняшнее число по местному времени — тем же видом, каким его понимает
/// сервер. Местное, а не серверное: часовой пояс телефона свой, и в час
/// пополуночи серверное «сегодня» бывает вчерашним.
String today([DateTime? now]) {
  final date = now ?? DateTime.now();
  final month = date.month.toString().padLeft(2, "0");
  final day = date.day.toString().padLeft(2, "0");
  return "${date.year}-$month-$day";
}

/// Имя с прописной буквы — церковнославянское в том числе.
///
/// Словарь лексем хранит леммы строчными («нікола́й», «і҆ѡа́ннъ»), и склонение
/// выдаёт их такими же. В записке имя пишут с прописной: это имя человека, а не
/// слово из словаря.
///
/// Ведущие надстрочные знаки пропускаем: слово может начинаться со звательца или
/// придыхания, и поднимать в верхний регистр надо БУКВУ, а не знак над нею.
String capitalize(String raw) {
  if (raw.isEmpty) return raw;

  final chars = raw.runes.toList();
  final at = chars.indexWhere(_isLetter);
  if (at < 0) return raw;

  final head = String.fromCharCodes(chars.sublist(0, at));
  final letter = String.fromCharCode(chars[at]).toUpperCase();
  final tail = String.fromCharCodes(chars.sublist(at + 1));

  return "$head$letter$tail";
}

/// U+0300–U+036F и U+0483–U+0489 — надстрочные знаки; буква стоит после них.
bool _isLetter(int rune) =>
    !((rune >= 0x0300 && rune <= 0x036F) || (rune >= 0x0483 && rune <= 0x0489));

/// Чин лица словами — в том роде, какой у лица.
///
/// Пока словарь не пришёл, чина не будет вовсе, и это верно: лучше без чина,
/// чем с чужим.
String rankLabel(Vocabulary vocabulary, Person person) =>
    vocabulary.rank(person.rank)?.formFor(person.sex).label ?? "";

/// Он же в родительном падеже гражданкой — так чин читается вслух.
String rankGenitive(Vocabulary vocabulary, NoteName name) =>
    vocabulary.rank(name.rank)?.formFor(name.sex).genitive ?? "";

/// Он же церковнославянским письмом.
///
/// **`null` — это ответ, а не пустота**: книжного написания этой пометы мы не
/// знаем, и подставлять вместо него гражданку молча нельзя. Показывающий обязан
/// на этот `null` посмотреть и сказать о нём словами.
String? rankChurchGenitive(Vocabulary vocabulary, NoteName name) =>
    vocabulary.rank(name.rank)?.formFor(name.sex).cs;
