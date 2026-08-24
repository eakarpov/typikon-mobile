import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/constants.dart';

/// Подписка на календарь чтений.
///
/// Лента `/calendar.ics` уже есть на сайте: скользящее окно в неделю назад и
/// три месяца вперёд, память и чтения дня, пересобирается раз в сутки.
/// Приложению остаётся отдать ссылку тому календарю, которым человек и так
/// пользуется, — дальше чтения приезжают к нему сами, без захода в приложение.

/// Открывает ленту в календаре устройства.
///
/// Сначала пробуем `webcal://` — эту схему календари понимают как «подписаться»
/// и дальше обновляют ленту сами. Если обработчика нет (на Android такое
/// обычно), отдаём тот же адрес по https: календарь предложит импортировать
/// файл, что хуже (разовый снимок вместо подписки), но лучше, чем ничего.
Future<void> openCalendarSubscription() async {
  final webcal = Uri.parse('webcal://$calendarFeedHost$calendarFeedPath');
  if (await canLaunchUrl(webcal)) {
    await launchUrl(webcal, mode: LaunchMode.externalApplication);
    return;
  }
  await launchUrl(Uri.parse(calendarFeedUrl), mode: LaunchMode.externalApplication);
}

Future<void> copyCalendarLink() async {
  await Clipboard.setData(const ClipboardData(text: calendarFeedUrl));
}

void showCalendarSubscriptionSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Чтения в вашем календаре",
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: "OldStandard"),
          ),
          const SizedBox(height: 12),
          const Text(
            "Память и чтения дня будут появляться в том календаре, которым вы уже "
            "пользуетесь: на неделю назад и на три месяца вперёд. Обновления "
            "календарь забирает сам, заходить в приложение для этого не нужно.",
            style: TextStyle(fontFamily: "OldStandard"),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.event_available),
              label: const Text("Открыть в календаре"),
              onPressed: () async {
                Navigator.pop(context);
                await openCalendarSubscription();
              },
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text("Скопировать ссылку"),
              onPressed: () async {
                Navigator.pop(context);
                await copyCalendarLink();
                Fluttertoast.showToast(
                  msg: "Ссылка скопирована",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.CENTER,
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Если кнопка не сработала, скопируйте ссылку и добавьте её вручную: "
            "в Google Календаре — «Другие календари» → «Добавить по URL».",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
