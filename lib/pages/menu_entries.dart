/// РАЗДЕЛЫ ПРИЛОЖЕНИЯ — ОДНОЙ ОПИСЬЮ.
///
/// Прежде меню было двадцатью пятью одинаковыми `ListTile` подряд в
/// `main_page.dart`: ни заголовков, ни разделителей, семь строк на пункт, и
/// каждый новый раздел удлинял свиток. Читателю это и видно — однородных
/// пунктов стало больше, чем глаз берёт за раз.
///
/// Теперь перечень — данные, и из них растут три вещи разом: ящик меню, экраны
/// «Собрание» и «Пособия» и тест, сверяющий описанные маршруты с тем, что умеет
/// разбирать `lib/routes.dart`. Расхождение меню и маршрутов молчаливо ровно до
/// того мига, когда читатель нажмёт пункт: приложение падает с «Could not find a
/// generator for route».
///
/// **Состав и деление взяты у сайта** (`src/app/NavMenu.tsx` в typikon-web),
/// вместе с его же основаниями: «Собрание» — то, что читают и поют, «Пособия» —
/// вспомогательное при чтении. Два перечня в двух хранилищах разойдутся, и
/// разойдутся молча, но разъезд имён разделов читатель заметит сам, а вот
/// разъезд правил показа — нет; поэтому здесь копия состава, а не правил.
library;

/// Кому пункт виден.
enum MenuVisibility {
  /// Всем.
  always,

  /// Вошедшему: личные разделы без учётной записи пусты.
  signedIn,
}

/// Пункт меню — он же строка экрана-раздела.
class MenuEntry {
  /// Как называется. Совпадает с заголовком самого экрана: разные имена одного
  /// места читаются как два разных места.
  final String title;

  /// Куда ведёт. Маршрут обязан разбираться `generateRoute` без аргумента.
  final String route;

  /// Чем этот раздел отличается от соседнего. Показывается только на
  /// экране-разделе: строка в ящике меню на пояснение места не имеет, и ради
  /// него экраны и заведены.
  final String? hint;

  final MenuVisibility visibility;

  const MenuEntry(
    this.title,
    this.route, {
    this.hint,
    this.visibility = MenuVisibility.always,
  });
}

/// Несколько пунктов под общим заголовком. Заголовок необязателен: первая
/// горстка пунктов в ящике заголовка не требует — она и есть «сегодня».
class MenuSection {
  final String? title;
  final List<MenuEntry> entries;

  const MenuSection({this.title, required this.entries});
}

const String corpusRoute = "/corpus";
const String handbookRoute = "/posobiya";

/// «Собрание» — то, что читают и поют.
const List<MenuEntry> corpusEntries = <MenuEntry>[
  MenuEntry("Библиотека", "/library",
      hint: "Книги собрания целиком, по оглавлению"),
  // Библия стоит отдельно от библиотеки: у неё своя навигация по канону и
  // параллельное чтение изданий, которых у обычной книги собрания нет.
  MenuEntry("Библия", "/bible",
      hint: "Канон целиком: главы, издания рядом, отзвуки"),
  MenuEntry("Зачала", "/pericopes",
      hint: "Чтения Апостола и Евангелия по зачалам"),
  // Каноны и акафисты — целые произведения со всеми песнями и строфами, в
  // отличие от песнопения, где единица выдачи — одна строка на своём месте
  // службы.
  MenuEntry("Каноны", "/canons", hint: "Целиком, со всеми песнями"),
  MenuEntry("Акафисты", "/akathists", hint: "Целиком, со всеми икосами"),
  MenuEntry("Молитвы", "/prayers", hint: "При памяти, при каноне, при акафисте"),
];

/// «Пособия» — вспомогательное при чтении.
const List<MenuEntry> handbookEntries = <MenuEntry>[
  // Знаки Типикона жили седьмой строкой в списке чужих сайтов — единственная
  // внутренняя ссылка среди внешних, и найти её там было нельзя.
  MenuEntry("Знаки Типикона", "/signs",
      hint: "Знак службы: что и когда поётся"),
  MenuEntry("Словарь", "/dictionary", hint: "Как прочесть и что значит слово"),
  MenuEntry("Именины", "/imeniny", hint: "По святцам — свой день"),
  MenuEntry("Хронология", "/chronology",
      hint: "Годы в обе стороны и разбор датировки"),
  MenuEntry("Полезные ресурсы", "/resources",
      hint: "Сайты, которыми пользуемся сами"),
];

/// Ящик меню. Всё, что не ушло в «Собрание» и «Пособия», плюс они сами.
const List<MenuSection> drawerSections = <MenuSection>[
  MenuSection(entries: <MenuEntry>[
    MenuEntry("Главная страница", "/"),
    MenuEntry("Чтения на календарный день", "/months"),
    MenuEntry("Памяти на день", "/dneslov/memories"),
    MenuEntry("Калькулятор чтений на день", "/calculator"),
  ]),
  MenuSection(title: "Круг года", entries: <MenuEntry>[
    MenuEntry("Триодион", "/triodion"),
    MenuEntry("Пятидесятница", "/penticostarion"),
    MenuEntry("Вне триодного цикла", "/outside"),
  ]),
  MenuSection(title: "Тексты", entries: <MenuEntry>[
    MenuEntry("Собрание", corpusRoute),
    MenuEntry("Пособия", handbookRoute),
  ]),
  MenuSection(title: "Моё", entries: <MenuEntry>[
    MenuEntry("Избранное", "/favourites"),
    MenuEntry("Мои заметки", "/notes", visibility: MenuVisibility.signedIn),
    MenuEntry("Помянник", "/pomyannik", visibility: MenuVisibility.signedIn),
    MenuEntry("Поданные записки", "/pomyannik/prinyatye",
        visibility: MenuVisibility.signedIn),
  ]),
  MenuSection(title: "Приложение", entries: <MenuEntry>[
    MenuEntry("Настройки", "/settings"),
    MenuEntry("Обратная связь", "/contact"),
  ]),
];

/// Все пункты описи разом — для теста и для сверки с маршрутами.
List<MenuEntry> get allMenuEntries => <MenuEntry>[
      for (final section in drawerSections) ...section.entries,
      ...corpusEntries,
      ...handbookEntries,
    ];
