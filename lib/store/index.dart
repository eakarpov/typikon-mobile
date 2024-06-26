import 'package:meta/meta.dart';

import "./models/models.dart";

@immutable
class AppState {
  final bool isLoading;
  final Settings settings;

  AppState({
    this.isLoading = false,
    this.settings = const Settings(),
  });

  factory AppState.init() => AppState(
    settings: Settings.init(),
  );

  AppState copyWith({
    bool isLoading = false,
    Settings settings = const Settings(),
  }) {
    return AppState(
      isLoading: isLoading ?? this.isLoading,
      settings: settings ?? this.settings,
    );
  }

  @override
  int get hashCode =>
      settings.hashCode ^
      isLoading.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AppState &&
              isLoading == other.isLoading &&
              settings == other.settings;

  @override
  String toString() {
    return 'AppState{isLoading: $isLoading, settings: $settings}';
  }

  Map<String, dynamic> toJson() {
    return {
      'settings': settings.toJson(),
    };
  }

  @override
  static AppState fromJson(dynamic json) {
    return AppState(
      settings: Settings.fromJson(json["settings"]),
    );
  }
}