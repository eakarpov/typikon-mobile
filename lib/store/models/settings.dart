import 'dart:ui';
import 'package:meta/meta.dart';

import 'package:typikon/models/color.dart';

@immutable
class Settings {
  final int fontSize;
  final Color backgroundColor;

  const Settings({ this.fontSize = 16, this.backgroundColor = const Color(0xffffffff) });

  factory Settings.init() => const Settings();

  Settings copyWith({int fontSize = 16, Color backgroundColor = const Color(0xffffffff) }) {
    return Settings(
      fontSize: fontSize,
      backgroundColor: backgroundColor,
    );
  }

  @override
  int get hashCode =>
      fontSize.hashCode ^ backgroundColor.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Settings &&
              fontSize == other.fontSize && backgroundColor == other.backgroundColor;

  @override
  String toString() {
    return 'Settings{fonSize: $fontSize; backgroundColor: ${HexColor.toHex(backgroundColor)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'backgroundColor': HexColor.toHex(backgroundColor),
    };
  }

  static fromJson(Map<String, dynamic> json) {
    return Settings(
      fontSize: json["fontSize"],
      backgroundColor: HexColor.fromHex(json["backgroundColor"]),
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