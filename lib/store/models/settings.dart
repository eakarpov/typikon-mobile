import 'dart:ui';
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

  const Settings({
    this.fontSize = 16,
    this.themeMode = ThemeMode.system,
    this.backgroundColor,
    this.fontColor,
    this.preloadTexts,
  });

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
  }) {
    return Settings(
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontColor: fontColor ?? this.fontColor,
      preloadTexts: preloadTexts ?? this.preloadTexts,
    );
  }

  @override
  int get hashCode =>
      fontSize.hashCode ^ themeMode.hashCode ^ backgroundColor.hashCode ^ fontColor.hashCode ^ preloadTexts.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Settings &&
              fontSize == other.fontSize &&
              themeMode == other.themeMode &&
              backgroundColor == other.backgroundColor &&
              fontColor == other.fontColor &&
              preloadTexts == other.preloadTexts;

  @override
  String toString() {
    return 'Settings{fonSize: $fontSize, themeMode: $themeMode, backgroundColor: ${backgroundColor == null ? 'null' : HexColor.toHex(backgroundColor!)}, fontColor: ${fontColor == null ? 'null' : HexColor.toHex(fontColor!)}, preloadTexts: $preloadTexts}';
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'themeMode': themeMode.name,
      'backgroundColor': backgroundColor == null ? null : HexColor.toHex(backgroundColor!),
      'fontColor': fontColor == null ? null : HexColor.toHex(fontColor!),
      'preloadTexts': preloadTexts,
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
    );
  }
}
