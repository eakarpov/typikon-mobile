import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Одна формулировка на все места, где может всплыть истёкшая сессия
/// (заметки, отчёт об ошибке) — текст должен быть везде один и тот же.
void showSessionExpiredToast() {
  Fluttertoast.showToast(
    msg: "Сессия истекла. Войдите снова в настройках",
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.CENTER,
    backgroundColor: Colors.red,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}
