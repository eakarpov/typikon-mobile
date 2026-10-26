import 'dneslov/images.dart';

// Досье святого и его житие — две разные вещи из двух разных ручек.
//
// SaintDossier — наша запись каталога: имя, чины, дни памяти, службы, тексты.
// SaintLife — житие из каталога памятей, притянутое нашим серверным прокси
// (ручка `/saints/dossier/{address}/life`; источник — в поле `source`). Они не
// сведены в один объект нарочно: жития нет у всякой записи, и когда его нет,
// имя святого, дни его памяти и тексты службы всё равно должны быть на экране.

// --- Житие --------------------------------------------------------------

/// Внешняя ссылка из жития — ресурс о святом на стороне источника.
class SaintLifeLink {
  final int id;
  final String url;

  const SaintLifeLink({required this.id, required this.url});

  factory SaintLifeLink.fromJson(Map<String, dynamic> json) =>
      SaintLifeLink(id: json["id"] ?? 0, url: json["url"] ?? "");
}

/// Одна память из жития. Описание у памяти может отсутствовать: сервер такие
/// опускает, и незагрузившимся текст это считаться не должно.
class SaintLifeMemo {
  final String title;

  /// Когда жил(а) святой — словами; чаще всего неизвестно.
  final String? happenedAt;
  final String description;

  const SaintLifeMemo({
    required this.title,
    this.happenedAt,
    this.description = "",
  });

  factory SaintLifeMemo.fromJson(Map<String, dynamic> json) => SaintLifeMemo(
    title: json["title"] ?? "",
    happenedAt: json["happenedAt"],
    description: json["description"] ?? "",
  );
}

class SaintLife {
  /// Слуг карточки памяти — внешний (у каталога памятей свои адреса), наш слуг
  /// ему не обязан совпадать. По нему открывается карточка на сайте источника.
  final String slug;

  /// Каталог, откуда житие: сегодня — всегда "dneslov", но поле в контракте,
  /// и выводить его снаружи незачем.
  final String source;
  final List<SaintLifeMemo> memoes;
  final List<SaintLifeLink> links;

  const SaintLife({
    required this.slug,
    this.source = "",
    this.memoes = const [],
    this.links = const [],
  });

  SaintLifeMemo? get memo =>
      memoes.where((m) => m.description.trim().isNotEmpty).firstOrNull;

  bool get hasText => (memo?.description ?? "").trim().isNotEmpty;

  factory SaintLife.fromJson(Map<String, dynamic> json) {
    final memoes = json["memoes"] is List ? json["memoes"] as List : const [];
    final links = json["links"] is List ? json["links"] as List : const [];

    return SaintLife(
      slug: json["slug"] ?? "",
      source: json["source"] ?? "",
      memoes: memoes.map((item) => SaintLifeMemo.fromJson(item)).toList(),
      links: links.map((item) => SaintLifeLink.fromJson(item)).toList(),
    );
  }
}

// --- Наша запись --------------------------------------------------------------

class SaintOrder {
  final String code;
  final String label;

  const SaintOrder({required this.code, required this.label});

  factory SaintOrder.fromJson(Map<String, dynamic> json) => SaintOrder(
    code: json["code"] ?? "",
    label: json["label"] ?? json["code"] ?? "",
  );
}

/// День памяти, разложенный в гражданский календарь.
///
/// [civil] и [iso] посчитаны сервером на день запроса: ближайшее выпадение, а
/// не «то же число этого года». Переходящие памяти иначе и не поставить —
/// в святцах они записаны смещением от Пасхи.
class SaintMemoryDate {
  /// Как записано в святцах — «05.09».
  final String raw;

  /// По юлианскому счёту — «5 сентября».
  final String julian;

  /// Ближайшее выпадение по гражданскому — «18 сентября 2026».
  final String civil;

  final String? iso;

  /// Пояснение от святцев, если есть: перенесение, обретение, собор.
  final String? note;

  const SaintMemoryDate({
    required this.raw,
    required this.julian,
    required this.civil,
    this.iso,
    this.note,
  });

  factory SaintMemoryDate.fromJson(Map<String, dynamic> json) =>
      SaintMemoryDate(
        raw: json["raw"] ?? "",
        julian: json["julian"] ?? "",
        civil: json["civil"] ?? "",
        iso: json["iso"],
        note: json["note"],
      );
}

/// Память в богослужебной книге — то есть служба, а не просто дата.
class SaintMemory {
  final String memoryId;
  final String label;

  /// Адрес в книге — «Минея, 30 августа».
  final String? address;

  /// Знак службы. Слуг корпуса (`slavoslovie`), а не знак месяцеслова —
  /// подписывается `serviceSignLabel`, см. `lib/utils/singing_labels.dart`.
  final String? sign;

  const SaintMemory({
    required this.memoryId,
    required this.label,
    this.address,
    this.sign,
  });

  factory SaintMemory.fromJson(Map<String, dynamic> json) => SaintMemory(
    memoryId: json["memoryId"] ?? "",
    label: json["label"] ?? "",
    address: json["address"],
    sign: json["sign"],
  );
}

/// Текст корпуса в перечне — без содержимого.
///
/// Не [Reading]: у того обязательны `content` и `readiness`, а досье отдаёт
/// перечень, а не тексты. Пропихнуть сюда `Reading.fromJson` значило бы уронить
/// разбор на `null` в непустом по типу поле.
class SaintText {
  final String id;
  final String name;
  final String? description;
  final String? author;

  const SaintText({
    required this.id,
    required this.name,
    this.description,
    this.author,
  });

  factory SaintText.fromJson(Map<String, dynamic> json) => SaintText(
    id: json["id"] ?? "",
    name: json["name"] ?? "",
    description: json["description"],
    author: json["author"],
  );
}

class SaintAkathist {
  final String? id;
  final String? title;
  final String? memory;
  final int? stanzas;

  const SaintAkathist({this.id, this.title, this.memory, this.stanzas});

  factory SaintAkathist.fromJson(Map<String, dynamic> json) => SaintAkathist(
    id: json["id"]?.toString(),
    title: json["title"],
    memory: json["memory"],
    stanzas: json["stanzas"] is int ? json["stanzas"] : null,
  );
}

class SaintDedication {
  final String slug;
  final String? short;
  final String? label;

  /// Сколько храмов с этим посвящением в каталоге.
  final int count;

  const SaintDedication({
    required this.slug,
    this.short,
    this.label,
    this.count = 0,
  });

  String get name => (short ?? "").isNotEmpty ? short! : (label ?? slug);

  factory SaintDedication.fromJson(Map<String, dynamic> json) =>
      SaintDedication(
        slug: json["slug"] ?? "",
        short: json["short"],
        label: json["label"],
        count: json["count"] is int ? json["count"] : 0,
      );
}

class SaintNoble {
  final String id;
  final String? name;

  const SaintNoble({required this.id, this.name});

  factory SaintNoble.fromJson(Map<String, dynamic> json) =>
      SaintNoble(id: json["id"]?.toString() ?? "", name: json["name"]);
}

class SaintDossier {
  final String? slug;

  /// Имя из нашей записи. Шапка страницы берёт его, а не заголовок жития:
  /// жития нет у всякой записи, и когда его нет, имя должно остаться.
  final String name;

  /// Прочие именования: варианты, прозвания, мирское имя при монашеском.
  final List<String> altNames;

  final String? kindLabel;
  final List<SaintOrder> orders;

  /// Опорный год словами — «342», «50 до Р. Х.». Пустой у тех, чьё время
  /// неизвестно, и придумывать его на месте из [baseYear] не нужно: у чисел до
  /// Рождества знак минуса читателю ничего не скажет.
  final String? baseYearLabel;

  final List<SaintMemoryDate> memoryDates;

  /// Оплечный образ для заголовка карточки.
  final String? roundelUrl;
  final List<DneslovImageDItem> images;
  final List<String> dneslovIds;

  /// Внешние ключи. Номеров святцев у одного лица бывает несколько: календарь
  /// разводит порознь мирское и монашеское имя, лицо и перенесение мощей.
  final Map<String, String> externals;

  final List<SaintMemory> memories;
  final List<SaintText> texts;
  final List<SaintText> mentions;

  /// `null` — корпус певческих текстов на сервере не выложен, акафистов мы не
  /// смотрели вовсе; `[]` — смотрели и не нашли. Разница та же, что между
  /// `corpus_unavailable` и пустой выдачей поиска, и схлопывать её нельзя:
  /// «акафистов нет» — утверждение, которого мы не делали.
  final List<SaintAkathist>? akathists;

  final List<SaintDedication> dedications;
  final SaintNoble? noble;

  /// Оговорка о непроставленных связях. Приходит от сервера, а не сочиняется
  /// на месте: без неё пустой раздел читается как утверждение, а связи выверены
  /// меньше чем наполовину.
  final String? caveat;

  const SaintDossier({
    required this.name,
    this.slug,
    this.altNames = const [],
    this.kindLabel,
    this.orders = const [],
    this.baseYearLabel,
    this.memoryDates = const [],
    this.roundelUrl,
    this.images = const [],
    this.dneslovIds = const [],
    this.externals = const {},
    this.memories = const [],
    this.texts = const [],
    this.mentions = const [],
    this.akathists,
    this.dedications = const [],
    this.noble,
    this.caveat,
  });

  bool get akathistsUnknown => akathists == null;

  static List<T> _list<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parse,
  ) => raw is List
      ? raw.map((item) => parse(item as Map<String, dynamic>)).toList()
      : <T>[];

  factory SaintDossier.fromJson(Map<String, dynamic> json) {
    final externals = <String, String>{};
    if (json["externals"] is List) {
      for (final item in json["externals"] as List) {
        final source = item["source"];
        final id = item["id"];
        if (source is String && id != null) {
          externals.putIfAbsent(source, () => id.toString());
        }
      }
    }

    final akathists = json["akathists"];

    return SaintDossier(
      slug: json["slug"],
      name: json["name"] ?? "",
      altNames: json["altNames"] is List
          ? List<String>.from(json["altNames"])
          : const [],
      kindLabel: json["kindLabel"],
      orders: _list(json["orders"], SaintOrder.fromJson),
      baseYearLabel: json["baseYearLabel"],
      memoryDates: _list(json["memoryDates"], SaintMemoryDate.fromJson),
      roundelUrl: json["roundelUrl"],
      externals: externals,
      dneslovIds: json['externals'] is List
          ? (json['externals'] as List)
                .whereType<Map>()
                .where((r) => r['source'] == 'dneslov' && r['id'] != null)
                .map((r) => r['id'].toString())
                .toSet()
                .toList()
          : const [],
      images: DneslovImageListD.fromJson(json['images'] ?? const []).list,
      memories: _list(json["memories"], SaintMemory.fromJson),
      texts: _list(json["texts"], SaintText.fromJson),
      mentions: _list(json["mentions"], SaintText.fromJson),
      akathists: akathists == null
          ? null
          : _list(akathists, SaintAkathist.fromJson),
      dedications: _list(json["dedications"], SaintDedication.fromJson),
      noble: json["noble"] is Map ? SaintNoble.fromJson(json["noble"]) : null,
      caveat: json["caveat"],
    );
  }
}
