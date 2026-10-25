library;

/// Псалтирь: кафизмы, статьи и окончания стихословия.
///
/// Константы — порт из typikon-rules (`src/psalter.py:69-93`): границы кафизм
/// и деление на статьи — не наше изобретение, славянская Псалтирь разделена
/// на двадцать кафизм раз и навсегда, и спорить с этим делением незачем.
/// Какая кафизма читается в какой день — другой вопрос; он у сервера
/// (`/api/v2/ordo/day`), а здесь только неизменное устройство книги.

/// Двадцать кафизм: номер → (первый псалом, последний). Славянский счёт:
/// глава Библии `psaltir` — это и есть псалом. 17-я кафизма — одна 118-я
/// («Непорочны»); на этом её особом положении держится половина уставных
/// правил о ней.
const Map<int, (int, int)> kathismaRanges = <int, (int, int)>{
  1: (1, 8),
  2: (9, 16),
  3: (17, 23),
  4: (24, 31),
  5: (32, 36),
  6: (37, 45),
  7: (46, 54),
  8: (55, 63),
  9: (64, 69),
  10: (70, 76),
  11: (77, 84),
  12: (85, 90),
  13: (91, 100),
  14: (101, 104),
  15: (105, 108),
  16: (109, 117),
  17: (118, 118),
  18: (119, 133),
  19: (134, 142),
  20: (143, 150),
};

/// Кафизмы, которыми кончается каждая из трёх слав: номер кафизмы →
/// (псалом, которым кончается ПЕРВАЯ статья, псалом, которым кончается
/// ВТОРАЯ). Проверено по образцу: шестая кафизма — это 37–39 / 40–42 / 43–45.
///
/// У 17-й кафизмы здесь записи нет: она делится не псалмами, а стихами
/// 118-го (см. [statii17]) — единственное исключение.
const Map<int, (int, int)> statiiRanges = <int, (int, int)>{
  1: (3, 6),
  2: (10, 13),
  3: (17, 20),
  4: (26, 29),
  5: (33, 34),
  6: (39, 42),
  7: (48, 50),
  8: (57, 60),
  9: (66, 67),
  10: (71, 73),
  11: (77, 80),
  12: (87, 88),
  13: (93, 96),
  14: (102, 103),
  15: (105, 106),
  16: (112, 115),
  18: (123, 128),
  19: (136, 139),
  20: (144, 147),
};

/// 17-я кафизма делится стихами 118-го псалма: после 72-го и после 131-го
/// (статьи 1–72 / 73–131 / 132–176).
const (int, int) statii17 = (72, 131);

/// Пс 151 в кафизмы не входит, но существует — дополнительный псалом,
/// семь стихов. Показываем отдельным пунктом.
const int psalm151 = 151;
const int psalm151VerseCount = 7;

/// Последний псалом Псалтири в славянском счёте.
const int lastPsalm = 150;

/// Есть ли такая кафизма.
bool isKathismaNumber(int number) => kathismaRanges.containsKey(number);

/// Псалмы кафизмы по её номеру. Пусто — такой кафизмы нет.
List<int> kathismaPsalms(int number) {
  final range = kathismaRanges[number];
  if (range == null) return const <int>[];
  return List<int>.generate(range.$2 - range.$1 + 1, (i) => range.$1 + i);
}

/// Одна статья (слава) кафизмы. Обычные кафизмы делятся псалмами; у 17-й
/// псалом один (118), и статьи режутся стихами — тогда [firstVerse] и
/// [lastVerse] не null.
class Statia {
  final int firstPsalm;
  final int lastPsalm;
  final int? firstVerse;
  final int? lastVerse;

  const Statia.psalms(this.firstPsalm, this.lastPsalm)
    : firstVerse = null,
      lastVerse = null;

  const Statia.verses(int psalm, this.firstVerse, this.lastVerse)
    : firstPsalm = psalm,
      lastPsalm = psalm;

  bool get isVerseBased => firstVerse != null;
}

/// Статьи кафизмы — ровно три. Так устроена вся Псалтирь, и без этого
/// деления кафизма неотличима от простого списка псалмов.
List<Statia> kathismaStatii(int number) {
  if (number == 17) {
    return const <Statia>[
      Statia.verses(118, 1, 72),
      Statia.verses(118, 73, 131),
      Statia.verses(118, 132, 176),
    ];
  }
  final psalms = kathismaPsalms(number);
  final edges = statiiRanges[number];
  if (psalms.isEmpty || edges == null) return const <Statia>[];
  final first = edges.$1, second = edges.$2;
  return <Statia>[
    Statia.psalms(psalms.first, first),
    Statia.psalms(first + 1, second),
    Statia.psalms(second + 1, psalms.last),
  ];
}

/// Точка разбиения кафизмы на статьи: после какого псалма (у 17-й — после
/// какого стиха Пс 118) ставится разделитель. У всякой кафизмы две такие
/// точки: после первой и после второй статьи.
class StatiaEdge {
  final int psalm;
  final int? verse;

  const StatiaEdge.psalm(this.psalm) : verse = null;
  const StatiaEdge.verse(this.psalm, this.verse);
}

/// Где ставить разделитель между статьями кафизмы.
List<StatiaEdge> kathismaBreakEdges(int number) {
  if (number == 17) {
    // Не const-список: поля записи statii17 в константном выражении
    // недоступны, а дублировать числа 72/131 третьей копией незачем.
    return <StatiaEdge>[
      StatiaEdge.verse(118, statii17.$1),
      StatiaEdge.verse(118, statii17.$2),
    ];
  }
  final edges = statiiRanges[number];
  if (edges == null) return const <StatiaEdge>[];
  return <StatiaEdge>[StatiaEdge.psalm(edges.$1), StatiaEdge.psalm(edges.$2)];
}

/// Имя кафизмы для списка и шапки: «1-я кафизма».
String kathismaTitle(int number) => "$number-я кафизма";

/// Ключ записи прогресса чтения: кафизмы — `psalter:kathisma:<n>`,
/// дополнительный псалом — `psalter:psalm:151`.
String kathismaProgressId(int number) =>
    number == psalm151 ? "psalter:psalm:151" : "psalter:kathisma:$number";

/// Имя записи для списка «продолжить чтение»: «Псалтирь: 1-я кафизма».
String kathismaProgressName(int number) => number == psalm151
    ? "Псалтирь: псалом 151"
    : "Псалтирь: ${kathismaTitle(number)}";

/// Прогресс чтения кафизмы долей скролла → сколько статей прочитано.
/// Доля 0.95 и выше запись не достаёт: там прогресс стирается самим
/// хранилищем как «дочитано».
int statiiRead(double fraction) {
  if (fraction <= 0) return 0;
  final read = (fraction * 3).round();
  return read.clamp(0, 3);
}

/// Кончает ли псалом кафизму — последний ли он в какой-нибудь из двадцати.
/// «Подряд» в поминальном режиме вставляет молитвы после границ кафизм,
/// и граница эта — по последнему псалму (у 17-й — по одному Пс 118).
bool endsKathisma(int psalm) =>
    kathismaRanges.values.any((range) => range.$2 == psalm);

/// День сорокоуста от даты преставления: день преставления — первый,
/// сороковой — через тридцать девять. `null` — даты нет или она лежит
/// впереди (не бывает, и считать по ней нечего).
///
/// Считаем по календарным дням, не по суткам: «сегодня» и «дата» сводятся
/// к полуночной границе, иначе час чтения сдвигал бы день на единицу.
int? sorokoustDay(String? diedIso, DateTime now) {
  final died = DateTime.tryParse(diedIso ?? "");
  if (died == null) return null;
  final from = DateTime(died.year, died.month, died.day);
  final to = DateTime(now.year, now.month, now.day);
  final day = to.difference(from).inDays + 1;
  return day >= 1 ? day : null;
}

/// Кафизма сорокоустного дня: первая — первая кафизма, дальше по кругу.
int sorokoustKathisma(int day) => ((day - 1) % 20) + 1;

/// ОКОНЧАНИЯ СТИХОСЛОВИЯ. Sync с rules/texts/okonchaniya.yaml — там лежит
/// «окончание стихословия» (rules-okonchaniya-005): им кончается каждая
/// слава кафизмы и каждый отдельный псалом, стихословимый на службе:
/// «Слава Отцу и Сыну и Святому Духу, и ныне и присно и во веки веков.
/// Аминь. Аллилуия, аллилуия, аллилуия, слава Тебе, Боже. (трижды)».
/// Здесь — краткие формулы чтения по кафизмам; сверка полных текстов с
/// книгой отложена (см. отчёт этапа).

/// Короткое окончание, которым разделитель статьи подписан у 17-й кафизмы
/// (она делится стихами, и форма её разделителя — «Слава, и ныне»).
const String psalmodyEnd = "Слава, и ныне:";

const String psalterDoxology =
    'Слава Отцу и Сыну и Святому Духу, и ныне и присно и во веки веков. Аминь.';

/// Разделитель после статьи (славы): после него начинается следующая
/// статья кафизмы.
const String statiaBreak = "Господи, помилуй (трижды). Слава, и ныне:";

/// Конец кафизмы: аллилуарий после третьей статьи и краткая ектения.
/// «Хвалите имя Господне» (Пс 135) из полного правила здесь НЕ приводится —
/// без сверки с книгой выдумывать не будем.
const String kathismaEnd =
    "Аллилуия, аллилуия, аллилуия, слава Тебе, Боже (трижды). Господи, помилуй (трижды).";
