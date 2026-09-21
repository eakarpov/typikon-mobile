import "../dto/common.dart";
import "../apiMapper/reading.dart";
import "../apiMapper/calendar.dart";
import "../dto/text.dart";

/// Всё, что показывает главная: день и «что пополнилось».
///
/// **Запросы идут разом, а не очередью.** Второй от первого не зависит, и
/// ждать его по порядку значило удваивать время открытия на медленной сети.
///
/// **Отказ «последних текстов» дню не помеха.** Это отдельная вкладка и малый
/// список; прежде его отказ пробрасывался наружу и гасил всю главную — все три
/// вкладки показывали «не удалось загрузить чтения дня», хотя день был получен
/// и разобран. Так и случилось, когда списочная ручка перестала отдавать
/// `content`: разбор списка падал, а вместе с ним падало всё.
///
/// День же — то, ради чего страницу открывают, и его отказ остаётся отказом.
Future<MainPageData> updateData(String dateTime) async {
  final lastTexts = _lastTextsOrNothing();
  final day = await getCalendarDay(dateTime);

  return MainPageData(day: day, lastTexts: await lastTexts);
}

Future<ReadingList?> _lastTextsOrNothing() async {
  try {
    return await getLastTexts();
  } catch (_) {
    // Вкладка покажет пустой список: сказать тут нечего, а день важнее.
    return null;
  }
}
