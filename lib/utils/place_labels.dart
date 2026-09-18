// Подписи мест.
//
// Сервер шлёт коды — `settlement`, `identified_with`, `csl`, — а русских слов к
// ним не шлёт: перечни закрыты и лежат в самом корпусе. Поэтому имена здесь, и
// всякий незнакомый код показывается **как есть**, а не прячется и не
// подменяется «прочим»: заведут в корпусе новый род места — читатель увидит его
// непереведённым, но увидит.
//
// Тот же уговор, что в `singing_labels.dart` и `lexeme_labels.dart`. Исключение —
// досье святого: там подписи приходят с сервера, потому что словарь чужой
// (днеслов) и мы им не распоряжаемся. Здесь распоряжаемся.

const Map<String, String> _kinds = {
  "settlement": "город",
  "region": "область",
  "mountain": "гора",
  "river": "река",
  "sea": "море",
  "lake": "озеро",
  "valley": "долина",
  "spring": "источник",
  "desert": "пустыня",
  "island": "остров",
  "monastery": "обитель",
  "building": "постройка",
  "route": "путь",
  "other": "место",
};

const Map<String, String> _statuses = {
  "extant": "существует",
  "ruins": "в развалинах",
  "lost": "местоположение утрачено",
  "uncertain": "отождествление спорно",
};

/// Какого рода имя. Порядок — от древнего к нынешнему, как на странице сайта.
const Map<String, String> _roles = {
  "biblical": "В Писании",
  "slavonic": "По-славянски",
  "historical": "В истории",
  "modern": "Ныне",
  "variant": "Иначе",
};

const List<String> roleOrder = ["biblical", "slavonic", "historical", "modern", "variant"];

const Map<String, String> _confidences = {
  "certain": "надёжно",
  "probable": "вероятно",
  "disputed": "спорно",
};

/// Подписи связей с обоих концов: одна и та же запись читается по-разному, смотря
/// с какой стороны на неё глядеть.
const Map<String, List<String>> _relations = {
  // [от этого места, к этому месту]
  "succeeds": ["Преемник", "Предшественник"],
  "identified_with": ["Отождествляется с", "Отождествляется с"],
  "part_of": ["В пределах", "Включает"],
  "located_in": ["Находится в", "Здесь находится"],
  "near": ["Рядом", "Рядом"],
};

const Map<String, String> _languages = {
  "ru": "по-русски",
  "csl": "по-славянски",
  "cu": "по-славянски",
  "grc": "по-гречески",
  "el": "по-гречески",
  "heb": "по-еврейски",
  "he": "по-еврейски",
  "lat": "по-латыни",
  "la": "по-латыни",
  "ar": "по-арабски",
  "tr": "по-турецки",
  "en": "по-английски",
};

const Map<String, String> _sources = {
  "wikidata": "Викиданные",
  "pleiades": "Pleiades",
  "openbible": "OpenBible",
  "nikifor": "Энциклопедия Никифора",
  "editor": "правка редактора",
  "slavic-map": "карта славянских поселений",
};

String placeKindLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_kinds[code] ?? code);

String placeStatusLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_statuses[code] ?? code);

String placeRoleLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_roles[code] ?? code);

String placeConfidenceLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_confidences[code] ?? code);

String placeLangLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_languages[code] ?? code);

String placeSourceLabel(String? code) =>
    code == null || code.isEmpty ? "" : (_sources[code] ?? code);

/// Подпись связи с той стороны, с которой на неё смотрят.
String placeRelationLabel(String? type, String? direction) {
  final pair = _relations[type];
  if (pair == null) return type ?? "";
  return direction == "in" ? pair[1] : pair[0];
}

/// Год: отрицательный — до Рождества Христова.
String placeYearLabel(int year) =>
    year < 0 ? "${-year} до Р. Х." : "$year";

/// Промежуток лет словами. Пусто — когда не известно ни начала, ни конца.
String placeSpanLabel(int? from, int? to) {
  if (from == null && to == null) return "";
  if (from != null && to != null) return "${placeYearLabel(from)} — ${placeYearLabel(to)}";
  if (from != null) return "с ${placeYearLabel(from)}";
  return "до ${placeYearLabel(to!)}";
}

/// Куда ведёт ключ во внешней базе.
///
/// У OpenBible два раздела, и различаются они первой буквой ключа: `a` —
/// древние места, `m` — нынешние. Ошибка здесь тиха: ссылка открывается и ведёт
/// в чужую запись.
String? placeExternalUrl(String source, String id) {
  if (id.isEmpty) return null;
  switch (source) {
    case "wikidata":
      return "https://www.wikidata.org/wiki/$id";
    case "pleiades":
      return "https://pleiades.stoa.org/places/$id";
    case "openbible":
      final section = id.startsWith("a") ? "ancient" : "modern";
      return "https://www.openbible.info/geo/$section/$id";
    default:
      // nikifor — статья нашего же корпуса, она показывается ссылкой на чтение,
      // а не внешним адресом; editor и прочее внешнего адреса не имеют вовсе.
      return null;
  }
}

/// Место на карте — чужим приложением, своей карты у нас нет.
///
/// OpenStreetMap, а не `geo:`: вторая схема есть только на Android, и на iOS
/// открытие такой ссылки кончается отказом.
String placeMapUrl(double latitude, double longitude) =>
    "https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=11/$latitude/$longitude";
