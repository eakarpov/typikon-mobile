import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import "package:flutter_colorpicker/flutter_colorpicker.dart";
import 'dart:ui';

import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/api/cached_fetch.dart';
import 'package:typikon/apiMapper/auth.dart' as auth_api;

class SettingsPage extends StatefulWidget {
  const SettingsPage(context, {super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

typedef OnFontSizeChange = Function(int fontSize);

class _SettingsPageState extends State<SettingsPage> {

  void onPress() {
    StoreProvider.of<AppState>(context).dispatch(ChangeFontSizeAction(StoreProvider.of<AppState>(context).state.settings.fontSize + 1));
  }

  void onClearCache(BuildContext context) async {
    await clearHttpCache();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Кэш очищен")),
    );
  }

  bool _authInProgress = false;

  void onSignIn(BuildContext context) async {
    if (_authInProgress) return;
    setState(() { _authInProgress = true; });
    try {
      await auth_api.signInWithGoogle(StoreProvider.of<AppState>(context));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Не удалось войти: $e")),
        );
      }
    } finally {
      if (mounted) setState(() { _authInProgress = false; });
    }
  }

  void onSignOut(BuildContext context) async {
    if (_authInProgress) return;
    setState(() { _authInProgress = true; });
    try {
      await auth_api.signOut(StoreProvider.of<AppState>(context));
    } finally {
      if (mounted) setState(() { _authInProgress = false; });
    }
  }

  void onOpenPicker(BuildContext context, Color value, void Function(Color) cb) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick a color!'),
        content: SingleChildScrollView(
          child: MaterialPicker(
            pickerColor: value,
            onColorChanged: cb,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Настройки", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: StoreConnector<AppState, SettingsViewModel>(
        converter: (store) => SettingsViewModel.build(store),
        builder: (context, viewModel) {
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 20, left: 16, right: 16),
                    child: Text("Тема оформления", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text("Системная")),
                        ButtonSegment(value: ThemeMode.light, label: Text("Светлая")),
                        ButtonSegment(value: ThemeMode.dark, label: Text("Тёмная")),
                      ],
                      selected: {viewModel.themeMode},
                      onSelectionChanged: (selected) {
                        viewModel.onChangeThemeMode(selected.first);
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 20, left: 16),
                    child: GestureDetector(
                      onTap: () { viewModel.onChangeFontSize(viewModel.fontSize + 1); },
                      child: Text("Размер текста чтений", style: TextStyle(fontWeight: FontWeight.bold)),
                    )),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Slider(
                      value: viewModel.fontSize.toDouble(),
                      onChanged: (newValue) { viewModel.onChangeFontSize(newValue.toInt()); },
                      min: 5,
                      max: 40,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.all(12),
                    color: viewModel.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
                    child: Text(
                      "Пример того, как будет выглядеть текст.",
                      textAlign: TextAlign.justify,
                      style: TextStyle(
                          fontFamily: "OldStandard",
                          fontSize: viewModel.fontSize.toDouble(),
                          color: viewModel.fontColor ?? Theme.of(context).textTheme.bodyLarge?.color
                      ),
                    ),
                  ),
                  Padding(
                      padding: EdgeInsets.only(top: 20, left: 16, right: 16),
                      child: TextButton(
                            child: Text("Выбрать цвет фона текстов", style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                             onOpenPicker(context, viewModel.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor, viewModel.onChangeBackgroundColor);
                            },
                      ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      child: Text("Выбрать цвет шрифта текстов", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        onOpenPicker(context, viewModel.fontColor ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black, viewModel.onChangeFontColor);
                      },
                    ),
                  ),
                  if (viewModel.backgroundColor != null || viewModel.fontColor != null) Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      child: Text("Сбросить цвета чтений (следовать теме)"),
                      onPressed: viewModel.onResetReadingColors,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      child: Text("Очистить кэш"),
                      onPressed: () => onClearCache(context),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 20, left: 16, right: 16),
                    child: Text("Аккаунт", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: viewModel.isSignedIn
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Вы вошли как ${viewModel.email ?? viewModel.name ?? 'пользователь Google'}"),
                              TextButton(
                                child: Text(_authInProgress ? "Выходим…" : "Выйти"),
                                onPressed: _authInProgress ? null : () => onSignOut(context),
                              ),
                            ],
                          )
                        : TextButton(
                            child: Text(_authInProgress ? "Входим…" : "Войти через Google"),
                            onPressed: _authInProgress ? null : () => onSignIn(context),
                          ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}

class SettingsViewModel {
  final int fontSize;
  final Function(int) onChangeFontSize;

  final Color? backgroundColor;
  final Function(Color) onChangeBackgroundColor;

  final Color? fontColor;
  final Function(Color) onChangeFontColor;

  final ThemeMode themeMode;
  final Function(ThemeMode) onChangeThemeMode;

  final VoidCallback onResetReadingColors;

  final bool isSignedIn;
  final String? email;
  final String? name;

  SettingsViewModel({
    this.fontSize = 0,
    this.onChangeFontSize = SettingsViewModel.stub,
    this.fontColor,
    this.onChangeFontColor = SettingsViewModel.stubColor,
    this.backgroundColor,
    this.onChangeBackgroundColor = SettingsViewModel.stubColor,
    this.themeMode = ThemeMode.system,
    this.onChangeThemeMode = SettingsViewModel.stubThemeMode,
    this.onResetReadingColors = SettingsViewModel.stubVoid,
    this.isSignedIn = false,
    this.email,
    this.name,
  });

  static stub (int fontSize) {}

  static stubColor (Color backgroundColor) {}

  static stubThemeMode (ThemeMode themeMode) {}

  static stubVoid () {}

  static SettingsViewModel build(Store<AppState> store) {
    return SettingsViewModel(
      fontSize: store.state.settings.fontSize,
      onChangeFontSize: (newFontSize) {
        store.dispatch(ChangeFontSizeAction(newFontSize));
      },
      fontColor: store.state.settings.fontColor,
      onChangeFontColor: (newFontColor) {
        store.dispatch(ChangeFontColorAction(newFontColor));
      },
      backgroundColor: store.state.settings.backgroundColor,
      onChangeBackgroundColor: (newBackgroundColor) {
        store.dispatch(ChangeBackgroundColorAction(newBackgroundColor));
      },
      themeMode: store.state.settings.themeMode,
      onChangeThemeMode: (newThemeMode) {
        store.dispatch(ChangeThemeModeAction(newThemeMode));
      },
      onResetReadingColors: () {
        store.dispatch(ResetReadingColorsAction());
      },
      isSignedIn: store.state.auth.isSignedIn,
      email: store.state.auth.email,
      name: store.state.auth.name,
    );
  }
}

typedef OnChangeFontSize = int;
