import 'dart:ui';

import 'package:typikon/models/color.dart';

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
