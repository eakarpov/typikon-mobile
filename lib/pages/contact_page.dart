import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/apiMapper/contact.dart';

class ContactPage extends StatefulWidget {
  const ContactPage(context, {super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final TextEditingController emailField = TextEditingController();
  final TextEditingController themeField = TextEditingController();
  final TextEditingController messageField = TextEditingController();
  final TextEditingController tokenField = TextEditingController();

  String email = "";
  String theme = "";
  String message = "";
  String token = "";

  late Future<Uint8List> captcha;

  @override
  void initState() {
    super.initState();
    captcha = fetchCaptcha();
  }

  void onPress() async {
    final bool sent = await sendForm(email, theme, message, token);
    if (sent) {
      Fluttertoast.showToast(
          msg: "Сообщение отправлено успешно",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0
      );
      setState(() {
        email = "";
        theme = "";
        message = "";
        token = "";
      });
      emailField.clear();
      themeField.clear();
      messageField.clear();
      tokenField.clear();
    } else {
      Fluttertoast.showToast(
          msg: "Ошибка при отправке",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );
      setState(() {
        captcha = fetchCaptcha();
        token = "";
      });
      emailField.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Обратная связь", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(5.0),
              child: TextField(
                controller: emailField,
                onChanged: (value) {
                  setState(() {
                    email = value;
                  });
                },
                decoration: const InputDecoration(hintText: 'Ваш email'),
              )
            ),
            Padding(
              padding: EdgeInsets.all(5.0),
              child: TextField(
                controller: themeField,
                onChanged: (value) {
                  setState(() {
                    theme = value;
                  });
                },
                decoration: const InputDecoration(hintText: 'Тема письма'),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(5.0),
              child: TextField(
                controller: messageField,
                onChanged: (value) {
                  setState(() {
                    message = value;
                  });
                },
                maxLines: 8,
                decoration: const InputDecoration(hintText: 'Содержимое письма'),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(5.0),
              child: TextField(
                controller: tokenField,
                onChanged: (value) {
                  setState(() {
                    token = value;
                  });
                },
                decoration: const InputDecoration(hintText: 'Капча'),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(5.0),
              child: FutureBuilder(future: captcha, builder: (context, future) {
                if (future.hasData) {
                  return (
                      Image.memory(future.data!)
                  );
                }
                return Container();
              }),
            ),
            TextButton(onPressed: onPress, child: Text("Отправить"))
          ],
        ),
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