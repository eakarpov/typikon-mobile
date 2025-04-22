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
    var day = json == null ? null : CalendarDay.fromJson(json);
    var lastTexts = json2 == null ? null : ReadingList.fromJson(json2);
    return MainPageData(
      day: day,
      lastTexts: lastTexts,
    );
  }
}