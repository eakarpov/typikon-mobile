import 'package:flutter/material.dart';

/// Экран на случай маршрута, который открыть не вышло.
///
/// Разбор маршрутов отвечает `null`, когда имени не знает или аргумент не того
/// вида, — а без этого экрана `null` значил исключение навигатора и ничего на
/// экране. Сюда попадают не из меню, а из устаревшего уведомления, ссылки или
/// ошибки в данных, поэтому всё, что тут можно предложить, — вернуться.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Не найдено", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48.0),
              const SizedBox(height: 16.0),
              const Text(
                "Этот раздел открыть не удалось.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8.0),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text("Назад"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
