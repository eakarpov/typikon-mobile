import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:typikon/apiMapper/contact.dart';
import 'package:typikon/components/api_error_view.dart';

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

  late Future<Uint8List> captcha;

  /// Письмо уходит. Пока так — кнопка не нажимается: второе нажатие слало бы
  /// второе письмо с уже использованной капчей.
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    captcha = fetchCaptcha();
  }

  @override
  void dispose() {
    emailField.dispose();
    themeField.dispose();
    messageField.dispose();
    tokenField.dispose();
    super.dispose();
  }

  void _reloadCaptcha() {
    setState(() {
      captcha = fetchCaptcha();
    });
    tokenField.clear();
  }

  void _toast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: color,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void onPress() async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      final bool sent = await sendForm(
        emailField.text.trim(),
        themeField.text.trim(),
        messageField.text,
        tokenField.text.trim(),
      );
      if (!mounted) return;

      if (sent) {
        _toast("Сообщение отправлено успешно", Colors.green);
        emailField.clear();
        themeField.clear();
        messageField.clear();
        _reloadCaptcha();
      } else {
        _toast("Ошибка при отправке", Colors.red);
        // Капча одноразовая: после отказа нужна новая. Написанное не трогаем —
        // прежде здесь стирался адрес, а набирать его заново из-за неверно
        // прочитанной картинки незачем.
        _reloadCaptcha();
      }
    } catch (error) {
      if (!mounted) return;
      // Сеть пропала или сервер молчит: без этого нажатие не давало ничего.
      _toast(failureMessage(error, "письмо не отправлено"), Colors.red);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Обратная связь", style: TextStyle(fontFamily: "OldStandard")),
      ),
      // Прокручивается: с поднятой клавиатурой капча и «Отправить» уходили под
      // неё, и достать их было нечем.
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(5.0),
              child: TextField(
                controller: emailField,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Ваш email'),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(5.0),
              child: TextField(
                controller: themeField,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Тема письма'),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(5.0),
              child: TextField(
                controller: messageField,
                maxLines: 8,
                decoration: const InputDecoration(hintText: 'Содержимое письма'),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(5.0),
              child: TextField(
                controller: tokenField,
                decoration: const InputDecoration(hintText: 'Капча'),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(5.0),
              child: FutureBuilder(future: captcha, builder: (context, future) {
                if (future.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  );
                }
                if (future.hasData) {
                  return Image.memory(future.data!);
                }
                // Без картинки письмо не отправить, а пустое место на её месте
                // этого не объясняло.
                return Column(
                  children: [
                    Text(
                      isNetworkError(future.error)
                          ? "Нет связи: капча не загрузилась."
                          : "Капча не загрузилась.",
                      textAlign: TextAlign.center,
                    ),
                    TextButton(onPressed: _reloadCaptcha, child: const Text("Повторить")),
                  ],
                );
              }),
            ),
            TextButton(
              onPressed: _sending ? null : onPress,
              child: Text(_sending ? "Отправляется…" : "Отправить"),
            ),
          ],
        ),
      ),
    );
  }
}
