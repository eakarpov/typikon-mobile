// Помянник — перечень ЛИЦ, а не список строк: у каждого своё имя, свой чин и
// свои даты, и от них считаются дни, ради которых помянник и заводят.
//
// Счёт этих дней здесь не воспроизводится НИ В ОДНОЙ строке. День преставления
// считается первым, оттого третий день — через двое суток, девятый — через
// восемь, сороковой — через тридцать девять; всякая попытка повторить это на
// своей стороне ошибётся на день и ровно в ту сторону, где день пропускают.
// Даты приходят посчитанными, и здесь их только разбирают.

/// Разворот помянника. На бумаге он разграфлён так же, и переучивать человека,
/// у которого этот разворот перед глазами двадцать лет, незачем.
const String living = "living";
const String departed = "departed";

class NameDay {
  /// `auto` — посчитано по дню рождения и святцам; `manual` — названо человеком.
  final String source;

  /// В каком календаре записаны месяц и число. `old` — как в святцах: сдвиг
  /// календарей ложится в разные годы по-разному, и заранее переведённое число
  /// однажды разошлось бы с месяцесловом.
  final String? style;

  final int? month;
  final int? day;

  /// Подвижная память: смещение от Пасхи в днях. Числа у неё нет вовсе.
  final int? offset;

  final String? saint;

  const NameDay({
    required this.source,
    this.style,
    this.month,
    this.day,
    this.offset,
    this.saint,
  });

  bool get movable => offset != null;

  factory NameDay.fromJson(Map<String, dynamic> json) => NameDay(
        source: json["source"] ?? "auto",
        style: json["style"],
        month: json["month"],
        day: json["day"],
        offset: json["offset"],
        saint: json["saint"],
      );

  Map<String, dynamic> toJson() => {
        "source": source,
        if (style != null) "style": style,
        if (month != null) "month": month,
        if (day != null) "day": day,
        if (offset != null) "offset": offset,
        if (saint != null) "saint": saint,
      };
}

class Sorokoust {
  final String from;
  final String? where;

  const Sorokoust({required this.from, this.where});

  factory Sorokoust.fromJson(Map<String, dynamic> json) =>
      Sorokoust(from: json["from"] ?? "", where: json["where"]);

  Map<String, dynamic> toJson() => {"from": from, if (where != null) "where": where};
}

class Person {
  final String id;

  /// Как ввёл человек. Его написание мы не переписываем без спроса.
  final String name;

  /// Церковная форма, если подсказали и он согласился: «Георгий» при «Юрии».
  final String? churchName;

  final String kind;
  final String? sex;
  final String? rank;

  /// «Мама», «крёстный» — чтобы хозяин не спутал двух Николаев. В записку не
  /// идёт: там поминают по имени, а не по родству.
  final String? relation;

  final String? born;
  final String? baptized;
  final String? died;
  final NameDay? nameDay;
  final Sorokoust? sorokoust;
  final List<String> groups;
  final int order;

  const Person({
    required this.id,
    required this.name,
    this.churchName,
    this.kind = living,
    this.sex,
    this.rank,
    this.relation,
    this.born,
    this.baptized,
    this.died,
    this.nameDay,
    this.sorokoust,
    this.groups = const [],
    this.order = 0,
  });

  bool get isDeparted => kind == departed;

  /// Имя для показа: «Георгий (Юрий)», когда наречение отличается от привычного.
  String get display =>
      (churchName ?? "").isEmpty || churchName == name ? name : "$churchName ($name)";

  /// Имя, каким лицо поминают, — оно же уходит в записку.
  String get commemorated => (churchName ?? "").isEmpty ? name : churchName!;

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: json["id"] ?? "",
        name: json["name"] ?? "",
        churchName: json["churchName"],
        kind: json["kind"] ?? living,
        sex: json["sex"],
        rank: json["rank"],
        relation: json["relation"],
        born: json["born"],
        baptized: json["baptized"],
        died: json["died"],
        nameDay: json["nameDay"] is Map ? NameDay.fromJson(json["nameDay"]) : null,
        sorokoust: json["sorokoust"] is Map ? Sorokoust.fromJson(json["sorokoust"]) : null,
        groups: json["groups"] is List ? List<String>.from(json["groups"]) : const [],
        order: json["order"] is int ? json["order"] : 0,
      );

  /// Что уходит на запись и на правку.
  ///
  /// Правка отправляется ЛИЦОМ ЦЕЛИКОМ, а не изменёнными полями: сервер иначе не
  /// смог бы отличить «не трогай» от «сотри», и на этом вопросе рано или поздно
  /// теряется дата преставления. Поэтому здесь `null` пишутся явно, а не
  /// опускаются, — в отличие от [NameDay.toJson], где они значат другое.
  Map<String, dynamic> toInput() => {
        "name": name,
        "churchName": churchName,
        "kind": kind,
        "sex": sex,
        "rank": rank,
        "relation": relation,
        "born": born,
        "baptized": baptized,
        "died": died,
        "nameDay": nameDay?.toJson(),
        "sorokoust": sorokoust?.toJson(),
      };

  Person copyWith({
    String? name,
    Object? churchName = _keep,
    String? kind,
    Object? sex = _keep,
    Object? rank = _keep,
    Object? relation = _keep,
    Object? born = _keep,
    Object? baptized = _keep,
    Object? died = _keep,
    Object? nameDay = _keep,
    Object? sorokoust = _keep,
  }) =>
      Person(
        id: id,
        name: name ?? this.name,
        churchName: churchName == _keep ? this.churchName : churchName as String?,
        kind: kind ?? this.kind,
        sex: sex == _keep ? this.sex : sex as String?,
        rank: rank == _keep ? this.rank : rank as String?,
        relation: relation == _keep ? this.relation : relation as String?,
        born: born == _keep ? this.born : born as String?,
        baptized: baptized == _keep ? this.baptized : baptized as String?,
        died: died == _keep ? this.died : died as String?,
        nameDay: nameDay == _keep ? this.nameDay : nameDay as NameDay?,
        sorokoust: sorokoust == _keep ? this.sorokoust : sorokoust as Sorokoust?,
        groups: groups,
        order: order,
      );
}

/// Часовой для `copyWith`: без него «не передали» и «передали null» неразличимы,
/// а здесь это разница между «оставить дату» и «стереть её».
const Object _keep = Object();

/// Дни поминовения усопшего — посчитанные сервером.
class MemorialCount {
  final String third;
  final String ninth;
  final String fortieth;

  /// Идут ли ещё сорок дней. Считается на день запроса и само собою протухает:
  /// записанная в базу помета осталась бы навсегда и пошла бы в записку через
  /// десять лет после погребения.
  final bool newlyDeparted;

  final int years;

  const MemorialCount({
    required this.third,
    required this.ninth,
    required this.fortieth,
    required this.newlyDeparted,
    required this.years,
  });

  factory MemorialCount.fromJson(Map<String, dynamic> json) => MemorialCount(
        third: json["third"] ?? "",
        ninth: json["ninth"] ?? "",
        fortieth: json["fortieth"] ?? "",
        newlyDeparted: json["newlyDeparted"] == true,
        years: json["years"] is int ? json["years"] : 0,
      );
}

/// Срок сорокоуста. Это **не** сороковой день: сорокоуст считается со дня
/// заказа, и заказанный на девятый день кончится на сорок восьмой.
class SorokoustSpan {
  final String from;
  final String to;
  final int passed;
  final int left;

  /// В самый сороковой день — ещё нет: литургию этого дня служат, и «окончено»,
  /// пока имя читают, было бы неправдой.
  final bool done;

  const SorokoustSpan({
    required this.from,
    required this.to,
    required this.passed,
    required this.left,
    required this.done,
  });

  factory SorokoustSpan.fromJson(Map<String, dynamic> json) => SorokoustSpan(
        from: json["from"] ?? "",
        to: json["to"] ?? "",
        passed: json["passed"] is int ? json["passed"] : 0,
        left: json["left"] is int ? json["left"] : 0,
        done: json["done"] == true,
      );
}

class PersonCard {
  /// На какое число посчитано. Всё остальное — «на сегодня» и протухает в
  /// полночь: карточку, пролежавшую открытой через полночь, надо перезапросить.
  final String on;

  final Person person;
  final MemorialCount? memorial;
  final SorokoustSpan? sorokoust;

  const PersonCard({
    required this.on,
    required this.person,
    this.memorial,
    this.sorokoust,
  });

  bool staleOn(String today) => on.isNotEmpty && on != today;

  factory PersonCard.fromJson(Map<String, dynamic> json) => PersonCard(
        on: json["on"] ?? "",
        person: Person.fromJson(json["person"] ?? const {}),
        memorial: json["memorial"] is Map ? MemorialCount.fromJson(json["memorial"]) : null,
        sorokoust: json["sorokoust"] is Map ? SorokoustSpan.fromJson(json["sorokoust"]) : null,
      );
}

class UpcomingEvent {
  final String date;
  final String kind;

  /// Пусто у общих поминальных дней — они не про кого-то одного.
  final String? personId;

  final String? name;
  final int? years;
  final String title;

  /// День не уставный: определение Собора, указ или местный обычай. Помету
  /// обязан донести и показ — список без неё выглядит уставным целиком.
  final bool custom;

  final String? note;

  const UpcomingEvent({
    required this.date,
    required this.kind,
    required this.title,
    this.personId,
    this.name,
    this.years,
    this.custom = false,
    this.note,
  });

  factory UpcomingEvent.fromJson(Map<String, dynamic> json) => UpcomingEvent(
        date: json["date"] ?? "",
        kind: json["kind"] ?? "",
        title: json["title"] ?? "",
        personId: json["personId"],
        name: json["name"],
        years: json["years"] is int ? json["years"] : null,
        custom: json["custom"] == true,
        note: json["note"],
      );

  Map<String, dynamic> toJson() => {
        "date": date,
        "kind": kind,
        "title": title,
        if (personId != null) "personId": personId,
        if (name != null) "name": name,
        if (years != null) "years": years,
        if (custom) "custom": true,
        if (note != null) "note": note,
      };
}

class Upcoming {
  /// С какого дня посчитано. Подвижные памяти и годовщины считаются от него, и
  /// окно, посчитанное вчера, начинается вчера.
  final String from;

  final int days;
  final List<UpcomingEvent> events;

  const Upcoming({required this.from, required this.days, this.events = const []});

  factory Upcoming.fromJson(Map<String, dynamic> json) => Upcoming(
        from: json["from"] ?? "",
        days: json["days"] is int ? json["days"] : 0,
        events: json["events"] is List
            ? (json["events"] as List).map((e) => UpcomingEvent.fromJson(e)).toList()
            : const [],
      );
}

class MemorialDay {
  final String date;
  final String name;
  final bool custom;
  final String? note;

  const MemorialDay({
    required this.date,
    required this.name,
    this.custom = false,
    this.note,
  });

  factory MemorialDay.fromJson(Map<String, dynamic> json) => MemorialDay(
        date: json["date"] ?? "",
        name: json["name"] ?? "",
        custom: json["custom"] == true,
        note: json["note"],
      );
}

// --- Словари ------------------------------------------------------------------

class RankForm {
  final String label;
  final String genitive;

  /// Церковнославянское начертание. **`null` значит «книгой не подтверждено»**,
  /// а не «нет формы»: у пяти помет подтверждения не нашлось, и придумывать за
  /// книгу мы не станем. Записка обязана поставить такую помету гражданкой и
  /// сказать об этом словами.
  final String? cs;

  const RankForm({required this.label, required this.genitive, this.cs});

  factory RankForm.fromJson(Map<String, dynamic> json) => RankForm(
        label: json["label"] ?? "",
        genitive: json["genitive"] ?? "",
        cs: json["cs"],
      );
}

class RankInfo {
  final String key;
  final RankForm masculine;
  final RankForm? feminine;

  /// Только живым, только усопшим или всё равно.
  final String? only;

  const RankInfo({required this.key, required this.masculine, this.feminine, this.only});

  RankForm formFor(String? sex) => sex == "f" && feminine != null ? feminine! : masculine;

  bool suits(String kind) => only == null || only == kind;

  factory RankInfo.fromJson(Map<String, dynamic> json) => RankInfo(
        key: json["key"] ?? "",
        masculine: RankForm.fromJson(json),
        feminine: json["feminine"] is Map ? RankForm.fromJson(json["feminine"]) : null,
        only: json["only"],
      );
}

class NoteKindInfo {
  final String key;
  final String label;

  /// Кого можно вписать: панихида о живых не служится, молебен об усопших — тоже.
  final String about;

  /// Сколько дней длится поминовение. 0 — разовое.
  final int days;

  final String note;

  const NoteKindInfo({
    required this.key,
    required this.label,
    required this.about,
    this.days = 0,
    this.note = "",
  });

  bool accepts(String kind) => about == "both" || about == kind;

  factory NoteKindInfo.fromJson(Map<String, dynamic> json) => NoteKindInfo(
        key: json["key"] ?? "",
        label: json["label"] ?? "",
        about: json["about"] ?? "both",
        days: json["days"] is int ? json["days"] : 0,
        note: json["note"] ?? "",
      );
}

class PomyannikLimits {
  final int maxPersons;
  final int maxBatch;
  final int maxNamesInNote;

  const PomyannikLimits({
    this.maxPersons = 500,
    this.maxBatch = 200,
    this.maxNamesInNote = 20,
  });

  factory PomyannikLimits.fromJson(Map<String, dynamic> json) => PomyannikLimits(
        maxPersons: json["maxPersons"] is int ? json["maxPersons"] : 500,
        maxBatch: json["maxBatch"] is int ? json["maxBatch"] : 200,
        maxNamesInNote: json["maxNamesInNote"] is int ? json["maxNamesInNote"] : 20,
      );
}

class Vocabulary {
  final List<RankInfo> ranks;
  final List<NoteKindInfo> noteKinds;
  final PomyannikLimits limits;

  const Vocabulary({
    this.ranks = const [],
    this.noteKinds = const [],
    this.limits = const PomyannikLimits(),
  });

  RankInfo? rank(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final item in ranks) {
      if (item.key == key) return item;
    }
    return null;
  }

  factory Vocabulary.fromJson(Map<String, dynamic> json) => Vocabulary(
        ranks: json["ranks"] is List
            ? (json["ranks"] as List).map((e) => RankInfo.fromJson(e)).toList()
            : const [],
        noteKinds: json["noteKinds"] is List
            ? (json["noteKinds"] as List).map((e) => NoteKindInfo.fromJson(e)).toList()
            : const [],
        limits: json["limits"] is Map
            ? PomyannikLimits.fromJson(json["limits"])
            : const PomyannikLimits(),
      );
}

// --- Записка ------------------------------------------------------------------

class NoteName {
  final String name;
  final String? churchName;

  /// Церковнославянское начертание в родительном падеже.
  final String? slavonic;

  /// Откуда оно взялось. `lexicon` — склонено по словарной схеме, это настоящий
  /// родительный. Прочее — падеж остался прежним, и выдать это за проверенный
  /// значило бы подсунуть читающему ошибку, которой он не делал.
  final String? slavonicSource;

  final String kind;
  final String? rank;
  final String? sex;

  const NoteName({
    required this.name,
    required this.kind,
    this.churchName,
    this.slavonic,
    this.slavonicSource,
    this.rank,
    this.sex,
  });

  bool get declined => slavonicSource == "lexicon";

  /// Что печатать на листе. Церковнославянское, если оно есть; иначе — то, как
  /// имя вписано, гражданкой.
  String get text => (slavonic ?? "").isNotEmpty
      ? slavonic!
      : ((churchName ?? "").isNotEmpty ? churchName! : name);

  factory NoteName.fromJson(Map<String, dynamic> json) => NoteName(
        name: json["name"] ?? "",
        kind: json["kind"] ?? living,
        churchName: json["churchName"],
        slavonic: json["slavonic"],
        slavonicSource: json["slavonicSource"],
        rank: json["rank"],
        sex: json["sex"],
      );
}

class NoteSpan {
  final String from;
  final String to;

  const NoteSpan({required this.from, required this.to});

  factory NoteSpan.fromJson(Map<String, dynamic> json) =>
      NoteSpan(from: json["from"] ?? "", to: json["to"] ?? "");
}

/// Записка до подачи — тот же лист, что уйдёт священнику.
class NoteSheet {
  final NoteKindInfo kind;
  final NoteSpan? span;
  final List<NoteName> names;

  const NoteSheet({required this.kind, this.span, this.names = const []});

  // Не `living`/`departed`: так зовутся сами разделы (константы вверху файла),
  // и геттеры с теми же именами заслонили бы их прямо внутри этого класса —
  // анализатор поймал это на первом же сравнении.
  Iterable<NoteName> get livingNames => names.where((n) => n.kind != departed);
  Iterable<NoteName> get departedNames => names.where((n) => n.kind == departed);

  /// Имена, которые мы не склонили. Сказать о них обязана и страница: без этого
  /// человек примет наш именительный за проверенный родительный.
  Iterable<NoteName> get undeclined => names.where((n) => !n.declined);

  factory NoteSheet.fromJson(Map<String, dynamic> json) => NoteSheet(
        kind: NoteKindInfo.fromJson(json["kind"] ?? const {}),
        span: json["span"] is Map ? NoteSpan.fromJson(json["span"]) : null,
        names: json["names"] is List
            ? (json["names"] as List).map((e) => NoteName.fromJson(e)).toList()
            : const [],
      );
}

/// Поданная записка.
class Zapiska {
  final String id;
  final String kind;
  final List<NoteName> names;

  /// Сколько имён было. Переживает чистку, когда сами имена уже стёрты: в
  /// записке имена третьих лиц, и держать их после поминовения не за что.
  final int namesCount;

  final NoteSpan? span;
  final DateTime? createdAt;
  final DateTime? readAt;
  final DateTime? finishedAt;
  final DateTime? sweptAt;

  const Zapiska({
    required this.id,
    required this.kind,
    this.names = const [],
    this.namesCount = 0,
    this.span,
    this.createdAt,
    this.readAt,
    this.finishedAt,
    this.sweptAt,
  });

  bool get unread => readAt == null;
  bool get swept => sweptAt != null;

  /// Длящееся поминовение, которое пора отметить оконченным.
  bool get finishable => span != null && readAt != null && finishedAt == null;

  static DateTime? _time(dynamic raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

  factory Zapiska.fromJson(Map<String, dynamic> json) => Zapiska(
        id: json["id"] ?? "",
        kind: json["kind"] ?? "",
        names: json["names"] is List
            ? (json["names"] as List).map((e) => NoteName.fromJson(e)).toList()
            : const [],
        namesCount: json["namesCount"] is int ? json["namesCount"] : 0,
        span: json["span"] is Map ? NoteSpan.fromJson(json["span"]) : null,
        createdAt: _time(json["createdAt"]),
        readAt: _time(json["readAt"]),
        finishedAt: _time(json["finishedAt"]),
        sweptAt: _time(json["sweptAt"]),
      );
}

/// Кто принимает записки — как он назван себе и читающему.
class Commemorator {
  final String title;
  final String? place;

  const Commemorator({required this.title, this.place});

  factory Commemorator.fromJson(Map<String, dynamic> json) =>
      Commemorator(title: json["title"] ?? "", place: json["place"]);
}

/// Поданные священнику записки.
class Prinyatye {
  final List<Zapiska> items;
  final int total;
  final int unread;
  final Commemorator commemorator;

  const Prinyatye({
    required this.commemorator,
    this.items = const [],
    this.total = 0,
    this.unread = 0,
  });

  factory Prinyatye.fromJson(Map<String, dynamic> json) => Prinyatye(
        items: json["items"] is List
            ? (json["items"] as List).map((e) => Zapiska.fromJson(e)).toList()
            : const [],
        total: json["total"] is int ? json["total"] : 0,
        unread: json["unread"] is int ? json["unread"] : 0,
        commemorator: Commemorator.fromJson(json["commemorator"] ?? const {}),
      );
}

// --- Сверка имени -------------------------------------------------------------

class NameSuggestion {
  final String name;

  /// Довод, по которому решает человек: «похоже на родительный падеж», «имя
  /// наречения», «похоже на описку». Показывать обязательно — верное
  /// исправление с неверным доводом человек примет или отвергнет наугад.
  final String why;

  const NameSuggestion({required this.name, required this.why});

  factory NameSuggestion.fromJson(Map<String, dynamic> json) =>
      NameSuggestion(name: json["name"] ?? "", why: json["why"] ?? "");
}

/// Что мы знаем об этом имени — до того, как оно легло в помянник.
///
/// Помянник хранит СЛОВАРНУЮ форму: от неё зависят память в святцах, сверка
/// наречения и склонение для записки. Написанное косвенным падежом — «о здравии
/// Анны», как помянник и читают вслух, — молча отказывает во всех трёх.
class NameCheck {
  final String name;

  /// `known` — имя есть в святцах; `civil` — есть подсказка; `unknown` — не
  /// нашлось. **Незнакомое принимается**: указатель выведен нами и неполон, и
  /// отвергать по нему имя человека нельзя.
  final String status;

  final List<NameSuggestion> suggestions;

  const NameCheck({required this.name, required this.status, this.suggestions = const []});

  bool get hasHint => suggestions.isNotEmpty;

  factory NameCheck.fromJson(Map<String, dynamic> json) => NameCheck(
        name: json["name"] ?? "",
        status: json["status"] ?? "unknown",
        suggestions: json["suggestions"] is List
            ? (json["suggestions"] as List).map((e) => NameSuggestion.fromJson(e)).toList()
            : const [],
      );
}
