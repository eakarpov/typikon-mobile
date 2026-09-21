import '../dto/calendar.dart';
import '../dto/text.dart';

class MainPageData {
  final CalendarDay? day;
  final ReadingList? lastTexts;

  const MainPageData({
    required this.day,
    required this.lastTexts,
  });

  factory MainPageData.fromJson(Map<String, dynamic> json, List<dynamic> json2) {
    // Проверок на null здесь не было смысла держать: оба разбора получают
    // непустые ответы по типу, и обе ветви «иначе» были мертвы.
    return MainPageData(
      day: CalendarDay.fromJson(json),
      lastTexts: ReadingList.fromJson(json2),
    );
  }
}