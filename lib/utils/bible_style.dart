import '../dto/bible.dart';

/// Каким шрифтом рисовать издание.
///
/// Выбор идёт по объявленному начертанию издания, а не по догадке о содержимом:
/// гадать по строке значит однажды угадать неверно на стихе из одних цифр.
///
/// В сборке два шрифта — Monomakh и OldStandard. Церковнославянское (`cu`) и
/// валашское (`ro_cyr`) начертания гражданским шрифтом не показать: в нём нет ни
/// титла, ни юса, и текст осыплется квадратами.
const String _churchFont = "Monomakh";
const String _civilFont = "OldStandard";

const Set<String> _churchScripts = {"cu", "ro_cyr"};

String bibleFontFamily(String language) =>
    _churchScripts.contains(language) ? _churchFont : _civilFont;

/// Начертания, которые сборка вообще умеет нарисовать.
///
/// Латиница и греческий берутся OldStandard; церковнославянское и валашское —
/// Monomakh. Всё прочее — нет: китайских иероглифов нет ни в одном из двух
/// шрифтов, а издание `zh-1910` сервер отдаёт наравне с остальными. Без этой
/// проверки читатель, выбравший его из любопытства, получил бы экран квадратов и
/// решил, что сломалось приложение.
///
/// Список именно разрешительный, а не запретительный: добавит веб японское или
/// армянское издание — приложение честно скажет, что нарисовать его не может,
/// вместо того чтобы попробовать и осыпаться.
const Set<String> _renderableScripts = {"cu", "ro_cyr", "grc", "la", "cyr", "lat"};

bool canRenderEdition(BibleEdition edition) =>
    _renderableScripts.contains(edition.language);

/// Почему издание нельзя показать — короткой строкой для списка выбора.
String? editionUnavailableReason(BibleEdition edition) =>
    canRenderEdition(edition) ? null : "нет шрифта для этого письма";
