import 'package:meta/meta.dart';

@immutable
class Settings {
  final int fontSize;

  const Settings({ this.fontSize = 16 });

  factory Settings.init() => const Settings();

  Settings copyWith({int fontSize = 16}) {
    return Settings(
      fontSize: fontSize,
    );
  }

  @override
  int get hashCode =>
      fontSize.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Settings &&
              fontSize == other.fontSize;

  @override
  String toString() {
    return 'Settings{fonSize: $fontSize}';
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
    };
  }

  static fromJson(Map<String, dynamic> json) {
    return Settings(
      fontSize: json["fontSize"]
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