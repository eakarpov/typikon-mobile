import 'package:flutter/material.dart';

/// «Войдите» — вместо содержимого личного раздела.
///
/// Отдельным видом, а не сообщением об ошибке: сессия сайта живёт час, и её
/// протухание — обычный ход событий для приложения, которое остаётся открытым
/// дольше. Показывать по такому поводу «не удалось загрузить» значило бы
/// пугать поломкой там, где надо просто войти.
class SignInNeeded extends StatelessWidget {
  const SignInNeeded({super.key, required this.message});

  /// Что именно за входом: «чтобы вести помянник», «чтобы подать записку».
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48.0),
            const SizedBox(height: 16.0),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8.0),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, "/settings"),
              child: const Text("Войти"),
            ),
          ],
        ),
      ),
    );
  }
}
