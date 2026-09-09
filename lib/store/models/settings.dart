import 'dart:ui';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:meta/meta.dart';
import 'package:flutter/material.dart';

import 'package:typikon/models/color.dart';

@immutable
class Settings {
  final int fontSize;
  final ThemeMode themeMode;
  final Color? backgroundColor;
  final Color? fontColor;

  /// Скачивать ли тексты дня заранее, чтобы они открывались без сети.
  ///
  /// Три состояния, а не два: `null` — пользователя ещё не спрашивали, и до
  /// ответа мы ничего не качаем. Предзагрузка тратит мобильный трафик, поэтому
  /// включаться сама она не должна, но и молча прятаться в настройках тоже:
  /// `null` — это ещё и признак, что главной странице нужно предложить.
  final bool? preloadTexts;

  /// Междустрочный интервал чтений.
  ///
  /// **Не украшение.** Церковнославянский набор несёт надстрочные знаки —
  /// ударения, титла, придыхания, — и при тесных строках они сливаются со
  /// строкой над собой. Полтора — то же значение, что взял сайт, и текст в
  /// обоих местах читается одинаково.
  final double lineHeight;

  /// Выключка чтений: `justify` или `left`.
  ///
  /// Переносов у нас нет, и выключка по ширине местами разгоняет пробелы до
  /// прогалин. Кому это мешает больше, чем неровный край, — выбирает левый.
  final String readingAlign;

  /// Наибольшая ширина колонки чтения в логических точках; `null` — во всю
  /// ширину.
  ///
  /// На телефоне разницы нет, и потому умолчание — во всю ширину. На планшете и
  /// в развороте строка во всю ширину заставляет глаз искать начало следующей.
  final double? readingMeasure;

  /// Показывать ли машинные ударения там, где корпус размечен не полностью.
  ///
  /// **Настройка читателя, а не свойство места.** У сайта она живёт в адресе
  /// страницы — там её причина в том, что чтение дают почитать по ссылке, и в
  /// ссылке должно быть видно, в каком виде текст показан. В приложении ссылки
  /// нет, зато есть тот же довод, что у выбора изданий Библии: кто читает вслух,
  /// хочет ударений везде, а не заново на каждом тексте.
  ///
  /// По умолчанию выключено: книга показывается такой, какая она есть.
  final bool showAccents;

  /// Кто шлёт напоминания помянника: `device` или `server`.
  ///
  /// **Различие честное, и в настройках оно названо словами.** Приложение
  /// напоминает всегда, в том числе без сети, но показывает напоминание тогда,
  /// когда система даст фоновой задаче окно, — то есть когда придётся, а иной
  /// день и никогда. Сервер будит в минуту, но только при сети и только если
  /// приложение не остановлено силой через настройки системы: остановленному
  /// Android не отдаёт толчков вовсе, и обойти это нельзя.
  ///
  /// Имена при этом не ездят ни в том, ни в другом случае: толчок пуст, а что
  /// сказать, решает то же правило в `utils/pomyannik_reminders.dart`.
  final String reminderSource;

  /// Издания Библии, выбранные читателем, в порядке выбора.
  ///
  /// Пустой список — «по умолчанию», а не «ни одного»: код издания по умолчанию
  /// не зашивается, он разрешается в рантайме по признаку эталона. Зашей мы
  /// `cs-eliz` — и получили бы шестую копию списка изданий, которая разошлась бы
  /// молча (см. `resolveEditionCodes`).
  ///
  /// Здесь, а не в адресе страницы: выбор изданий — настройка читателя, а не
  /// свойство места, и протаскивать его через каждый вход в главу пришлось бы
  /// шесть раз.
  final List<String> bibleEditions;

  const Settings({
    this.fontSize = 16,
    this.themeMode = ThemeMode.system,
    this.backgroundColor,
    this.fontColor,
    this.preloadTexts,
    this.lineHeight = 1.5,
    this.readingAlign = "justify",
    this.readingMeasure,
    this.reminderSource = "device",
    this.showAccents = false,
    this.bibleEditions = const [],
  });

  /// Ждать ли толчка с сервера.
  bool get remindsFromServer => reminderSource == "server";

  /// Качаем только по явному согласию.
  bool get isPreloadEnabled => preloadTexts == true;

  /// Спрашивать ли про предзагрузку — то есть не отвечал ли пользователь раньше.
  bool get shouldAskAboutPreload => preloadTexts == null;

  factory Settings.init() => const Settings();

  Settings copyWith({
    int? fontSize,
    ThemeMode? themeMode,
    Color? backgroundColor,
    Color? fontColor,
    bool? preloadTexts,
    double? lineHeight,
    String? readingAlign,
    // Отдельным признаком, потому что `null` здесь — это значение («во всю
    // ширину»), а не «не меняем»: без него ширину нельзя было бы сбросить.
    bool clearMeasure = false,
    double? readingMeasure,
    String? reminderSource,
    bool? showAccents,
    List<String>? bibleEditions,
  }) {
    return Settings(
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontColor: fontColor ?? this.fontColor,
      preloadTexts: preloadTexts ?? this.preloadTexts,
      lineHeight: lineHeight ?? this.lineHeight,
      readingAlign: readingAlign ?? this.readingAlign,
      readingMeasure: clearMeasure ? null : (readingMeasure ?? this.readingMeasure),
      reminderSource: reminderSource ?? this.reminderSource,
      showAccents: showAccents ?? this.showAccents,
      bibleEditions: bibleEditions ?? this.bibleEditions,
    );
  }

  @override
  int get hashCode =>
      fontSize.hashCode ^
      themeMode.hashCode ^
      backgroundColor.hashCode ^
      fontColor.hashCode ^
      preloadTexts.hashCode ^
      lineHeight.hashCode ^
      readingAlign.hashCode ^
      readingMeasure.hashCode ^
      reminderSource.hashCode ^
      showAccents.hashCode ^
      Object.hashAll(bibleEditions);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Settings &&
              fontSize == other.fontSize &&
              themeMode == other.themeMode &&
              backgroundColor == other.backgroundColor &&
              fontColor == other.fontColor &&
              preloadTexts == other.preloadTexts &&
              lineHeight == other.lineHeight &&
              readingAlign == other.readingAlign &&
              readingMeasure == other.readingMeasure &&
              reminderSource == other.reminderSource &&
              showAccents == other.showAccents &&
              listEquals(bibleEditions, other.bibleEditions);

  @override
  String toString() {
    return 'Settings{fonSize: $fontSize, themeMode: $themeMode, backgroundColor: ${backgroundColor == null ? 'null' : HexColor.toHex(backgroundColor!)}, fontColor: ${fontColor == null ? 'null' : HexColor.toHex(fontColor!)}, preloadTexts: $preloadTexts, bibleEditions: $bibleEditions}';
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'themeMode': themeMode.name,
      'backgroundColor': backgroundColor == null ? null : HexColor.toHex(backgroundColor!),
      'fontColor': fontColor == null ? null : HexColor.toHex(fontColor!),
      'preloadTexts': preloadTexts,
      'lineHeight': lineHeight,
      'readingAlign': readingAlign,
      'readingMeasure': readingMeasure,
      'reminderSource': reminderSource,
      'showAccents': showAccents,
      'bibleEditions': bibleEditions,
    };
  }

  static Settings fromJson(Map<String, dynamic> json) {
    // Персистентность до появления тёмной темы всегда писала явный белый/чёрный
    // как "дефолт" (поле themeMode тогда ещё не существовало). Такие значения —
    // не осознанный выбор пользователя, поэтому на миграции считаем их null,
    // чтобы старые пользователи сразу получили тёмную тему на странице чтения.
    final isLegacyState = !json.containsKey("themeMode");
    Color? backgroundColor = json["backgroundColor"] == null ? null : HexColor.fromHex(json["backgroundColor"]);
    Color? fontColor = json["fontColor"] == null ? null : HexColor.fromHex(json["fontColor"]);
    if (isLegacyState) {
      if (backgroundColor == const Color(0xffffffff)) backgroundColor = null;
      if (fontColor == const Color(0xff000000)) fontColor = null;
    }
    return Settings(
      fontSize: json["fontSize"] ?? 16,
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == json["themeMode"],
        orElse: () => ThemeMode.system,
      ),
      backgroundColor: backgroundColor,
      fontColor: fontColor,
      // Отсутствие ключа — это ровно "не спрашивали": у тех, кто обновился
      // с прежней версии, предзагрузка не включится сама, им предложат.
      preloadTexts: json["preloadTexts"] is bool ? json["preloadTexts"] as bool : null,
      // Ключей нет — значит состояние сохранено прежней версией, и читатель
      // получает те же умолчания, что и новый. Число может прийти целым: JSON
      // не различает 2 и 2.0, а `as double` на целом бросает.
      lineHeight: (json["lineHeight"] as num?)?.toDouble() ?? 1.5,
      readingAlign: json["readingAlign"] == "left" ? "left" : "justify",
      readingMeasure: (json["readingMeasure"] as num?)?.toDouble(),
      // Умолчание — приложение: толчки требуют и сети, и живого ключа доставки,
      // и включаться сами, без спроса, не должны.
      reminderSource: json["reminderSource"] == "server" ? "server" : "device",
      // Ключа нет — состояние прежней версии: книга показывается как есть.
      showAccents: json["showAccents"] == true,
      // Ключа нет — значит настройки сохранены прежней версией: пустой список
      // означает «по умолчанию», и старое состояние переживает обновление без
      // отдельной миграции.
      bibleEditions: json["bibleEditions"] is List
          ? List<String>.from((json["bibleEditions"] as List).whereType<String>())
          : const <String>[],
    );
  }
}
