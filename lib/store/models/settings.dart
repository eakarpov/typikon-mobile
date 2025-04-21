import 'dart:ui';
import 'package:meta/meta.dart';
import 'package:flutter/material.dart';

import 'package:typikon/models/color.dart';

@immutable
class Settings {
  final int fontSize;
  final Color backgroundColor;
  final Color fontColor;

  const Settings({
    this.fontSize = 16,
    this.backgroundColor = const Color(0xffffffff),
    this.fontColor = Colors.black,
  });

  factory Settings.init() => const Settings();

  Settings copyWith({
    int fontSize = 16,
    Color backgroundColor = const Color(0xffffffff),
    Color fontColor = Colors.black,
  }) {
    return Settings(
      fontSize: fontSize,
      backgroundColor: backgroundColor,
      fontColor: fontColor,
    );
  }

  @override
  int get hashCode =>
      fontSize.hashCode ^ backgroundColor.hashCode ^ fontColor.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Settings &&
              fontSize == other.fontSize &&
              backgroundColor == other.backgroundColor &&
              fontColor == other.fontColor;

  @override
  String toString() {
    return 'Settings{fonSize: $fontSize, backgroundColor: ${HexColor.toHex(backgroundColor)}, fontColor: ${HexColor.toHex(fontColor)}}';
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'backgroundColor': HexColor.toHex(backgroundColor),
      'fontColor': HexColor.toHex(fontColor),
    };
  }

  static fromJson(Map<String, dynamic> json) {
    return Settings(
      fontSize: json["fontSize"],
      backgroundColor: HexColor.fromHex(json["backgroundColor"]),
      fontColor: HexColor.fromHex(json["fontColor"]),
    );
  }

  // SettingsEntity toEntity() {
  //   return SettingsEntity(fontSize);
  // }
  //
  // static Settings fromEntity(SettingsEntity entity) {
  //   return Settings(
  //     entity.fontSize,
  //   );
  // }
}