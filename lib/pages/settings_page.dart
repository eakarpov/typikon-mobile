import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
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
    print(111);
    print('adadads');
    print(StoreProvider.of<AppState>(context).state.settings.fontSize);
    StoreProvider.of<AppState>(context).dispatch(ChangeFontSizeAction(StoreProvider.of<AppState>(context).state.settings.fontSize + 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Настройки"),
      ),
      body: StoreConnector<AppState, SettingsViewModel>(
        converter: (store) => SettingsViewModel.build(store),
        builder: (context, viewModel) {
          return Container(
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
                  style: TextStyle(fontFamily: "OldStandard", fontSize: viewModel.fontSize.toDouble()),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _onViewStateChanged(int fontSize) {
    print(fontSize);
    print("aaa");
  }
}

class SettingsViewModel {
  final int fontSize;
  final Function(int) onChangeFontSize;

  SettingsViewModel({this.fontSize = 0, this.onChangeFontSize = SettingsViewModel.stub });

  static stub (int fontSize) {}

  static SettingsViewModel build(Store<AppState> store) {
    return SettingsViewModel(
      fontSize: store.state.settings.fontSize,
      onChangeFontSize: (newFontSize) {
        store.dispatch(ChangeFontSizeAction(newFontSize));
      },
    );
  }
}

typedef OnChangeFontSize = int;