import 'package:meta/meta.dart';

import "./models/models.dart";

@immutable
class AppState {
  final bool isLoading;
  final Settings settings;
  final Common common;

  AppState({
    this.isLoading = false,
    this.settings = const Settings(),
    required this.common,
  });

  factory AppState.init() => AppState(
    settings: Settings.init(),
    common: Common.init(),
  );

  AppState copyWith({
    bool isLoading = false,
    Settings settings = const Settings(),
    Common? common = null,
  }) {
    return AppState(
      isLoading: isLoading ?? this.isLoading,
      settings: settings ?? this.settings,
      common: common ?? this.common,
    );
  }

  @override
  int get hashCode =>
      settings.hashCode ^
      isLoading.hashCode ^
      common.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AppState &&
              isLoading == other.isLoading &&
              settings == other.settings &&
              common == other.common;

  @override
  String toString() {
    return 'AppState{isLoading: $isLoading, settings: $settings, common: $common}';
  }

  Map<String, dynamic> toJson() {
    return {
      'settings': settings.toJson(),
      'common': common.toJson(),
    };
  }

  @override
  static AppState fromJson(dynamic json) {
    return AppState(
      settings: Settings.fromJson(json["settings"]),
      common: Common.fromJson(json["common"]),
    );
  }
}