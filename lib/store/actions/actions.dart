import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;

import 'package:typikon/models/color.dart';
import '../models/favourites.dart';

// abstract class AppActions {
//   ActionDispatcher<Settings> changeFontSizeAction;
//
//   final changeFontSizeAction = new ActionDispatcher<UpdateTodoActionPayload>(
//       'AppActions-updateTodoAction');
//
//   @override
//   void setDispatcher(Dispatcher dispatcher) {
//     changeFontSizeAction.setDispatcher(dispatcher);
//   }
// }

class FetchItemsAction {}

class AppNotLoadedAction {}

class AppLoadedAction {}

class AppSaveAdditional {}

class ChangeCommonDateAction {
  final DateTime date;

  ChangeCommonDateAction(this.date);

  @override
  String toString() {
    return 'ChangeCommonDateAction{date: $date}';
  }
}

class ChangeFontSizeAction {
  final int fontSize;

  ChangeFontSizeAction(this.fontSize);

  @override
  String toString() {
    return 'ChangeFontSizeAction{fontSize: $fontSize}';
  }
}

class ChangeFontColorAction {
  final Color fontColor;

  ChangeFontColorAction(this.fontColor);

  @override
  String toString() {
    return 'ChangeFontColorAction{fontColor: ${HexColor.toHex(fontColor)}}';
  }
}

class ChangeBackgroundColorAction {
  final Color backgroundColor;

  ChangeBackgroundColorAction(this.backgroundColor);

  @override
  String toString() {
    return 'ChangeBackgroundColorAction{backgroundColor: ${HexColor.toHex(backgroundColor)}}';
  }
}

class ChangeThemeModeAction {
  final ThemeMode themeMode;

  ChangeThemeModeAction(this.themeMode);

  @override
  String toString() {
    return 'ChangeThemeModeAction{themeMode: $themeMode}';
  }
}

class ChangePreloadTextsAction {
  final bool preloadTexts;

  ChangePreloadTextsAction(this.preloadTexts);

  @override
  String toString() {
    return 'ChangePreloadTextsAction{preloadTexts: $preloadTexts}';
  }
}

class ToggleFavouriteAction {
  final String textId;
  final DateTime at;

  ToggleFavouriteAction(this.textId, {DateTime? at}) : at = at ?? DateTime.now();

  @override
  String toString() {
    return 'ToggleFavouriteAction{textId: $textId, at: $at}';
  }
}

/// Список, пришедший с сервера.
class FavouritesLoadedAction {
  final List<String> textIds;

  FavouritesLoadedAction(this.textIds);

  @override
  String toString() {
    return 'FavouritesLoadedAction{count: ${textIds.length}}';
  }
}

/// Часть очереди доехала до сервера.
class FavouritesQueueConfirmedAction {
  final List<PendingFavourite> confirmed;

  FavouritesQueueConfirmedAction(this.confirmed);

  @override
  String toString() {
    return 'FavouritesQueueConfirmedAction{count: ${confirmed.length}}';
  }
}

/// Вход под другим аккаунтом: чужое избранное на устройстве оставаться не должно.
class FavouritesClearedAction {}

/// Состояние, поднятое из хранилища при запуске (вместе с недоехавшей очередью).
class FavouritesRestoredAction {
  final FavouritesState state;

  FavouritesRestoredAction(this.state);

  @override
  String toString() {
    return 'FavouritesRestoredAction{count: ${state.textIds.length}, pending: ${state.pending.length}}';
  }
}

class ResetReadingColorsAction {}

class SignInSuccessAction {
  final String userId;
  final String? email;
  final String? name;

  SignInSuccessAction({required this.userId, this.email, this.name});

  @override
  String toString() {
    return 'SignInSuccessAction{userId: $userId, email: $email}';
  }
}

class SignOutAction {}
