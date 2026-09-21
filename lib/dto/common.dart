import '../dto/calendar.dart';
import '../dto/text.dart';

class MainPageData {
  final CalendarDay? day;
  final ReadingList? lastTexts;

  const MainPageData({
    required this.day,
    required this.lastTexts,
  });

}