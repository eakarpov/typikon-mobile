import 'package:flutter/material.dart';

import 'package:typikon/pages/akathist_page.dart';
import 'package:typikon/pages/akathists_page.dart';
import 'package:typikon/pages/bible_chapter_page.dart';
import 'package:typikon/pages/bible_page.dart';
import 'package:typikon/pages/book_page.dart';
import 'package:typikon/pages/calculator_page.dart';
import 'package:typikon/pages/canon_page.dart';
import 'package:typikon/pages/canons_page.dart';
import 'package:typikon/pages/chronology_page.dart';
import 'package:typikon/pages/communion_page.dart';
import 'package:typikon/pages/contact_page.dart';
import 'package:typikon/pages/concordance_page.dart';
import 'package:typikon/pages/current_day_memories_page.dart';
import 'package:typikon/pages/days_page.dart';
import 'package:typikon/pages/dictionary_page.dart';
import 'package:typikon/pages/favourite_page.dart';
import 'package:typikon/pages/imeniny_page.dart';
import 'package:typikon/pages/incipit_page.dart';
import 'package:typikon/pages/library_page.dart';
import 'package:typikon/pages/main_page.dart';
import 'package:typikon/pages/month_page.dart';
import 'package:typikon/pages/months_page.dart';
import 'package:typikon/pages/notes_page.dart';
import 'package:typikon/pages/outside_page.dart';
import 'package:typikon/pages/penticostarion_page.dart';
import 'package:typikon/pages/pericope_page.dart';
import 'package:typikon/pages/pericopes_page.dart';
import 'package:typikon/pages/place_page.dart';
import 'package:typikon/pages/places_page.dart';
import 'package:typikon/pages/pomyannik_import_page.dart';
import 'package:typikon/pages/pomyannik_note_page.dart';
import 'package:typikon/pages/pomyannik_page.dart';
import 'package:typikon/pages/pomyannik_person_page.dart';
import 'package:typikon/pages/pomyannik_prinyatye_page.dart';
import 'package:typikon/pages/pomyannik_upcoming_page.dart';
import 'package:typikon/pages/posledovanie_page.dart';
import 'package:typikon/pages/prayer_page.dart';
import 'package:typikon/pages/prayers_page.dart';
import 'package:typikon/pages/psalter_page.dart';
import 'package:typikon/pages/kathisma_page.dart';
import 'package:typikon/pages/psalter_serial_page.dart';
import 'package:typikon/pages/psalter_sorokoust_page.dart';
import 'package:typikon/pages/resources_page.dart';
import 'package:typikon/pages/rule_page.dart';
import 'package:typikon/pages/rule_office_page.dart';
import 'package:typikon/pages/ordo_page.dart';
import 'package:typikon/pages/saint_page.dart';
import 'package:typikon/pages/menu_entries.dart';
import 'package:typikon/pages/search_page.dart';
import 'package:typikon/pages/section_page.dart';
import 'package:typikon/pages/settings_page.dart';
import 'package:typikon/pages/signs_page.dart';
import 'package:typikon/pages/text_page.dart';
import 'package:typikon/pages/triodion_page.dart';
import 'package:typikon/utils/bible_route.dart';
import 'package:typikon/utils/incipit_route.dart';

/// Адрес входящей ссылки вида `<prefix><аргумент>` без query-части и конечного
/// слэша: `https://www.typikon.info/reading/<id>` движок превращает в маршрут
/// с именем `/reading/<id>`, и сюда из него извлекается `<id>`. Возвращает
/// `null`, если после префикса ничего нет.
String? deepLinkArgument(String name, String prefix) {
  if (!name.startsWith(prefix)) return null;
  var argument = name.substring(prefix.length);
  final query = argument.indexOf("?");
  if (query != -1) argument = argument.substring(0, query);
  if (argument.endsWith("/")) {
    argument = argument.substring(0, argument.length - 1);
  }
  return argument.isEmpty ? null : argument;
}

/// КУДА ВЕДУТ МАРШРУТЫ ПРИЛОЖЕНИЯ.
///
/// Прежде этот разбор жил внутри `build` в `main.dart` — триста строк в замыкании,
/// которое неоткуда позвать. Отсюда и главная его беда: перечень маршрутов и
/// перечень пунктов меню (`lib/pages/menu_entries.dart`) расходились молча, а
/// узнавал об этом читатель, у которого пункт меню роняет приложение.
/// Вынесено сюда ради теста, который сверяет оба перечня.
///
/// **Умолчание `null` — не пустяк.** Вернув его, `MaterialApp` бросает
/// «Could not find a generator for route»: не пустой экран, а падение.
///
/// Соглашение о маршрутах: **один адрес служит и указателю, и карточке** —
/// аргумент-строка значит карточку, его отсутствие — указатель. Так устроены
/// `/library`, `/bible`, `/canons`, `/imeniny`, `/months`, `/pomyannik` и прочие.
Route<dynamic>? generateRoute(
  RouteSettings settings, {
  required bool hasSkippedUpdate,
  required ValueChanged<bool> skipUpdateWindow,
}) {
  final arguments = settings.arguments;
  final name = settings.name ?? "";

  // Входящие ссылки сайта: `/reading/<id>` ведёт в тот же экран текста, что и
  // кнопки приложения, `/bible/<книга>/<глава>` — в ту же главу Библии. Путь
  // целиком становится именем маршрута, поэтому разбирается здесь, а дальше
  // дело за обычными ветками `/reading` и `/bible`.
  final readingLink = deepLinkArgument(name, "/reading/");
  if (readingLink != null) {
    return generateRoute(
      RouteSettings(name: "/reading", arguments: readingLink),
      hasSkippedUpdate: hasSkippedUpdate,
      skipUpdateWindow: skipUpdateWindow,
    );
  }
  final bibleLink = deepLinkArgument(name, "/bible/");
  if (bibleLink != null) {
    return generateRoute(
      RouteSettings(name: "/bible", arguments: bibleLink),
      hasSkippedUpdate: hasSkippedUpdate,
      skipUpdateWindow: skipUpdateWindow,
    );
  }

  switch (settings.name) {
    // Аргумент необязателен, как у '/library': без него —
    // оглавление, с ним — глава. Разбор аргумента живёт в
    // utils/bible_route.dart, потому что собирают его из
    // нескольких мест сразу.
    case '/bible':
      if (arguments is String) {
        final target = parseBibleArgument(arguments);
        return MaterialPageRoute(
          builder: (context) {
            return BibleChapterPage(
              context,
              canonId: target.canonId,
              chapter: target.chapter,
              highlight: target.ranges,
            );
          },
        );
      } else {
        return MaterialPageRoute(
          builder: (context) {
            return BiblePage(context);
          },
        );
      }
    // У зачина нет своего идентификатора: ключ и есть
    // идентификатор. Поэтому аргумент несёт язык и ключ разом,
    // разбор — в utils/incipit_route.dart.
    case '/incipit':
      if (arguments is String) {
        final target = parseIncipitArgument(arguments);
        if (target.isValid) {
          return MaterialPageRoute(
            builder: (context) {
              return IncipitPage(
                context,
                language: target.language,
                incipit: target.incipit,
              );
            },
          );
        }
      }
      return null;
    case '/pericopes':
      return MaterialPageRoute(
        builder: (context) => PericopesPage(context),
      );
    case '/pericope':
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) => PericopePage(context, id: arguments),
        );
      }
      return null;
    // Где канонический стих стоит в изданиях собрания. Открывается из меню
    // выделения стиха Библии; аргумент — адрес «книга.глава.стих».
    case '/concordance':
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) => ConcordancePage(context, ref: arguments),
        );
      }
      return null;
    // Как у '/library' и '/bible': без аргумента список, с ним —
    // отдельная запись.
    case '/imeniny':
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) => NamePage(context, name: arguments),
        );
      }
      return MaterialPageRoute(
        builder: (context) => ImeninyPage(context),
      );
    case '/dictionary':
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) => LexemePage(context, id: arguments),
        );
      }
      return MaterialPageRoute(
        builder: (context) => DictionaryPage(context),
      );
    // Певческий корпус: три раздела по одному обычаю —
    // без аргумента перечень, с ним чтение целиком.
    case '/canons':
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) => CanonPage(context, id: arguments),
        );
      }
      return MaterialPageRoute(
        builder: (context) => CanonsPage(context),
      );
    case '/akathists':
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) => AkathistPage(context, id: arguments),
        );
      }
      return MaterialPageRoute(
        builder: (context) => AkathistsPage(context),
      );
    case '/prayers':
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) => PrayerPage(context, id: arguments),
        );
      }
      return MaterialPageRoute(
        builder: (context) => PrayersPage(context),
      );
    // Псалтирь: без аргумента список кафизм. Аргумент кафизмы — прежде
    // число 1..20 (или 151 — дополнительный псалом), с поминальным режимом —
    // строка «<число>|d»; разбор — в pages/kathisma_page.dart. «Подряд»
    // открывается без аргумента (с закладки), с аргументом-числом — с
    // названного псалма, строка «d»/«<псалом>|d» — поминальный режим.
    case '/psalter':
      return MaterialPageRoute(
        builder: (context) => const PsalterPage(),
      );
    // Молитвенное правило дня и подготовка к Причащению: состав секций
    // подбирается на самом экране, аргумент не нужен.
    case '/ordo':
      return MaterialPageRoute(builder: (context) => const OrdoPage());
    case practiceRoute:
      return MaterialPageRoute(builder: (context) => SectionPage(
        context, title: 'Правило', entries: practiceEntries,
      ));
    case '/rule/office':
      if (arguments is! RuleOfficeTarget) return null;
      return MaterialPageRoute(builder: (_) => RuleOfficePage(target: arguments));
    case '/rule':
      return MaterialPageRoute(
        builder: (context) => RulePage(context),
      );
    case '/communion':
      return MaterialPageRoute(
        builder: (context) => CommunionPage(context,
          initialDate: arguments is String ? DateTime.tryParse(arguments) : null,
        ),
      );
    // Чтение последования молитвослова: аргумент — `<key>|<lang>|<gender>|
    // <заголовок>`, разбор — в pages/posledovanie_page.dart.
    case '/posledovanie':
      if (arguments is String) {
        final target = parsePosledovanieArgument(arguments);
        if (target != null) {
          return MaterialPageRoute(
            builder: (context) => PosledovaniePage(
              context,
              title: target.title,
              posledovanieKey: target.key,
              lang: target.lang,
              gender: target.gender,
              part: target.part,
            ),
          );
        }
      }
      return null;
    case '/psalter/kathisma':
      final target = parseKathismaRouteArgument(arguments);
      if (target != null) {
        return MaterialPageRoute(
          builder: (context) =>
              KathismaPage(number: target.number, departed: target.departed),
        );
      }
      return null;
    case '/psalter/serial':
      final target = parseSerialRouteArgument(arguments);
      if (target != null) {
        return MaterialPageRoute(
          builder: (context) => PsalterSerialPage(
            chapter: target.chapter,
            departed: target.departed,
          ),
        );
      }
      return null;
    // Счётчик сорокоуста: выбор лица помянника и кафизма дня по дате
    // преставления. Открывается из списка Псалтири.
    case '/psalter/sorokoust':
      return MaterialPageRoute(
        builder: (context) => const PsalterSorokoustPage(),
      );
    case '/chronology':
      return MaterialPageRoute(
        builder: (context) => ChronologyPage(context),
      );
    case '/library':
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) {
            return BookPage(
              context,
              id: arguments,
            );
          },
        );
      } else {
        return MaterialPageRoute(
          builder: (context) {
            return LibraryPage(context);
          },
        );
      }
    case "/reading":
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) {
            return TextPage(
              context,
              id: arguments,
            );
          },
        );
      }
      return null;
    case "/settings":
      return MaterialPageRoute(
        builder: (context) {
          return SettingsPage(
            context,
          );
        },
      );
    case "/calculator":
      return MaterialPageRoute(
        builder: (context) {
          return CalculatorPage(
            context,
          );
        },
      );
    case "/saints":
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) {
            return SaintPage(
              context,
              id: arguments,
            );
          },
        );
      }
      // Досье без опознавателя не бывает: показывать нечего.
      return null;

    case "/places":
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) {
            return PlacePage(
              context,
              id: arguments,
            );
          },
        );
      }
      return MaterialPageRoute(
        builder: (context) => PlacesPage(context),
      );

    case "/triodion":
      return MaterialPageRoute(
        builder: (context) {
          return TriodionPage(
            context,
          );
        },
      );
    case "/penticostarion":
      return MaterialPageRoute(
        builder: (context) {
          return PenticostarionPage(
            context,
          );
        },
      );
    case "/search":
      return MaterialPageRoute(
        builder: (context) {
          return SearchPage(
            context,
          );
        },
      );
    case "/days":
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) {
            return DaysPage(
              context,
              id: arguments,
            );
          },
        );
      }
      // День без опознавателя не бывает: показывать нечего.
      return null;

    case "/months":
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) {
            return MonthPage(
              context,
              id: arguments,
            );
          },
        );
      } else {
        return MaterialPageRoute(
          builder: (context) {
            return MonthsPage(context);
          },
        );
      }
    case "/favourites":
      return MaterialPageRoute(
        builder: (context) {
          return FavouritePage(
            context,
          );
        },
      );
    // Как у '/library' и '/imeniny': без аргумента разворот
    // помянника, с ним — карточка лица.
    case "/pomyannik":
      if (arguments is String) {
        return MaterialPageRoute(
          builder: (context) => PomyannikPersonPage(context, id: arguments),
        );
      }
      return MaterialPageRoute(
        builder: (context) => PomyannikPage(context),
      );
    // Столбец берётся у вкладки, с которой пришли, — он и есть аргумент.
    case "/pomyannik/import":
      if (arguments is! String) return null;
      return MaterialPageRoute(
        builder: (context) => PomyannikImportPage(kind: arguments),
      );
    case "/pomyannik/upcoming":
      return MaterialPageRoute(
        builder: (context) => PomyannikUpcomingPage(context),
      );
    case "/pomyannik/zapiska":
      return MaterialPageRoute(
        builder: (context) => PomyannikNotePage(context),
      );
    case "/pomyannik/prinyatye":
      return MaterialPageRoute(
        builder: (context) => PomyannikPrinyatyePage(context),
      );
    case "/notes":
      return MaterialPageRoute(
        builder: (context) {
          return NotesPage(context);
        },
      );
    case "/contact":
      return MaterialPageRoute(
        builder: (context) {
          return ContactPage(
            context,
          );
        },
      );
    case "/day-saints":
      return MaterialPageRoute(
        builder: (context) {
          return CurrentDayMemoriesPage(context);
        },
      );
    // Два экрана-раздела: перечни берутся из описи меню, чтобы порядок и
    // пояснения не разъехались с ящиком.
    case corpusRoute:
      return MaterialPageRoute(
        builder: (context) => SectionPage(
          context,
          title: "Собрание",
          entries: corpusEntries,
        ),
      );
    case handbookRoute:
      return MaterialPageRoute(
        builder: (context) => SectionPage(
          context,
          title: "Пособия",
          entries: handbookEntries,
        ),
      );
    case "/resources":
      return MaterialPageRoute(
        builder: (context) {
          return ResourcesPage(context);
        },
      );
    case "/outside":
      return MaterialPageRoute(
        builder: (context) {
          return OutsidePage(context);
        },
      );
    case "/signs":
      return MaterialPageRoute(
        builder: (context) {
          return SignsPage(context);
        },
      );
    case "/":
      return MaterialPageRoute(
        builder: (context) {
          return MainPage(
            context,
            hasSkippedUpdate: hasSkippedUpdate,
            skipUpdateWindow: skipUpdateWindow,
          );
        },
      );
    default:
      return null;
  }
}
