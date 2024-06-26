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

class ChangeFontSizeAction {
  final int fontSize;

  ChangeFontSizeAction(this.fontSize);

  @override
  String toString() {
    return 'ChangeFontSizeAction{fontSize: $fontSize}';
  }
}
