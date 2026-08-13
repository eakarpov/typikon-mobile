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

  const Settings({
    this.fontSize = 16,
    this.themeMode = ThemeMode.system,
    this.backgroundColor,
    this.fontColor,
  });

  factory Settings.init() => const Settings();

  Settings copyWith({
    int? fontSize,
    ThemeMode? themeMode,
    Color? backgroundColor,
    Color? fontColor,
  }) {
    return Settings(
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontColor: fontColor ?? this.fontColor,
    );
  }

  @override
  int get hashCode =>
      fontSize.hashCode ^ themeMode.hashCode ^ backgroundColor.hashCode ^ fontColor.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Settings &&
              fontSize == other.fontSize &&
              themeMode == other.themeMode &&
              backgroundColor == other.backgroundColor &&
              fontColor == other.fontColor;

  @override
  String toString() {
    return 'Settings{fonSize: $fontSize, themeMode: $themeMode, backgroundColor: ${backgroundColor == null ? 'null' : HexColor.toHex(backgroundColor!)}, fontColor: ${fontColor == null ? 'null' : HexColor.toHex(fontColor!)}}';
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'themeMode': themeMode.name,
      'backgroundColor': backgroundColor == null ? null : HexColor.toHex(backgroundColor!),
      'fontColor': fontColor == null ? null : HexColor.toHex(fontColor!),
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
    );
  }
}
