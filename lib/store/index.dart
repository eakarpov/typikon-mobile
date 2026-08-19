import 'package:meta/meta.dart';

import "./models/models.dart";

@immutable
class AppState {
  final bool isLoading;
  final Settings settings;
  final Common common;
  final AuthState auth;

  AppState({
    this.isLoading = false,
    this.settings = const Settings(),
    required this.common,
    this.auth = const AuthState(),
  });

  factory AppState.init() => AppState(
    settings: Settings.init(),
    common: Common.init(),
    auth: AuthState.init(),
  );

  AppState copyWith({
    bool isLoading = false,
    Settings settings = const Settings(),
    Common? common = null,
    AuthState auth = const AuthState(),
  }) {
    return AppState(
      isLoading: isLoading ?? this.isLoading,
      settings: settings ?? this.settings,
      common: common ?? Common.init(),
      auth: auth ?? this.auth,
    );
  }

  @override
  int get hashCode =>
      settings.hashCode ^
      isLoading.hashCode ^
      common.hashCode ^
      auth.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AppState &&
              isLoading == other.isLoading &&
              settings == other.settings &&
              common == other.common &&
              auth == other.auth;

  @override
  String toString() {
    return 'AppState{isLoading: $isLoading, settings: $settings, common: $common, auth: $auth}';
  }

  Map<String, dynamic> toJson() {
    return {
      'settings': settings.toJson(),
      'common': common.toJson(),
      'auth': auth.toJson(),
    };
  }

  @override
  static AppState fromJson(dynamic json) {
    return AppState(
      settings: Settings.fromJson(json["settings"]),
      common: Common.fromJson(json["common"]),
      auth: AuthState.fromJson(json["auth"]),
    );
  }
}