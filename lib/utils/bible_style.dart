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

/// Отсутствие знака во встроенных шрифтах не запрещает чтение: Flutter
/// ищет его в системных запасных шрифтах Android/iOS. Покрытие конкретного
/// устройства нельзя определить по коду языка издания.
/// https://api.flutter.dev/flutter/painting/TextStyle/fontFamilyFallback.html
bool canRenderEdition(BibleEdition edition) => true;

String? editionUnavailableReason(BibleEdition edition) => null;
