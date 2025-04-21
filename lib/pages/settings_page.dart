import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import "package:flutter_colorpicker/flutter_colorpicker.dart";
import 'dart:ui';

import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/actions/actions.dart';

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
            color: viewModel.backgroundColor,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: GestureDetector(
                    onTap: () { viewModel.onChangeFontSize(viewModel.fontSize + 1); },
                    child: Text("Размер текста чтений", style: TextStyle(fontWeight: FontWeight.bold)),
                  )),
                Slider(
                  value: viewModel.fontSize.toDouble(),
                  onChanged: (newValue) { viewModel.onChangeFontSize(newValue.toInt()); },
                  min: 5,
                  max: 40,
                ),
                Text(
                  "Пример того, как будет выглядеть текст.",
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                      fontFamily: "OldStandard",
                      fontSize: viewModel.fontSize.toDouble(),
                      color: StoreProvider.of<AppState>(context).state.settings.fontColor
                  ),
                ),
                Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: TextButton(
                          child: Text("Выбрать цвет фона текстов", style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                           onOpenPicker(context, viewModel.backgroundColor, viewModel.onChangeBackgroundColor);
                          },
                    ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: TextButton(
                    child: Text("Выбрать цвет шрифта текстов", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      onOpenPicker(context, viewModel.fontColor, viewModel.onChangeFontColor);
                    },
                  ),
                ),
              ],
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

  final Color backgroundColor;
  final Function(Color) onChangeBackgroundColor;

  final Color fontColor;
  final Function(Color) onChangeFontColor;

  SettingsViewModel({
    this.fontSize = 0,
    this.onChangeFontSize = SettingsViewModel.stub,
    this.fontColor = const Color(0x00000000),
    this.onChangeFontColor = SettingsViewModel.stubColor,
    this.backgroundColor = const Color(0xffffffff),
    this.onChangeBackgroundColor = SettingsViewModel.stubColor,
  });

  static stub (int fontSize) {}

  static stubColor (Color backgroundColor) {}

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
    );
  }
}

typedef OnChangeFontSize = int;