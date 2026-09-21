import 'package:meta/meta.dart';

import "./models/models.dart";

@immutable
class AppState {
  final bool isLoading;
  final Settings settings;
  final Common common;
  final AuthState auth;
  final FavouritesState favourites;

  AppState({
    this.isLoading = false,
    this.settings = const Settings(),
    required this.common,
    this.auth = const AuthState(),
    this.favourites = const FavouritesState(),
  });

  factory AppState.init() => AppState(
    settings: Settings.init(),
    common: Common.init(),
    auth: AuthState.init(),
    favourites: FavouritesState.init(),
  );

  @override
  int get hashCode =>
      settings.hashCode ^
      isLoading.hashCode ^
      common.hashCode ^
      auth.hashCode ^
      favourites.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AppState &&
              isLoading == other.isLoading &&
              settings == other.settings &&
              common == other.common &&
              auth == other.auth &&
              favourites == other.favourites;

  @override
  String toString() {
    return 'AppState{isLoading: $isLoading, settings: $settings, common: $common, auth: $auth}';
  }

  Map<String, dynamic> toJson() {
    return {
      'settings': settings.toJson(),
      'common': common.toJson(),
      'auth': auth.toJson(),
      'favourites': favourites.toJson(),
    };
  }

  static AppState fromJson(dynamic json) {
    return AppState(
      settings: Settings.fromJson(json["settings"]),
      common: Common.fromJson(json["common"]),
      auth: AuthState.fromJson(json["auth"]),
      favourites: FavouritesState.fromJson(json["favourites"]),
    );
  }
}