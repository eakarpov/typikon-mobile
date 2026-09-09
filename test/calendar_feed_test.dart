import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/api/constants.dart';
import 'package:typikon/store/calendar_feed.dart';

// Переподписка на календарь. Ошибка здесь молчалива по самой природе подписки:
// лента перестаёт обновляться, и человек не видит ни ошибки, ни пустого экрана —
// просто новых событий больше нет.

void main() {
  test("подписанный на прежний адрес узнаёт о переезде", () {
    expect(subscriptionIsStale("https://www.typikon.su/calendar.ics"),
        calendarFeedUrl != "https://www.typikon.su/calendar.ics");
    expect(subscriptionIsStale("https://www.typikon.info/calendar.ics"),
        calendarFeedUrl != "https://www.typikon.info/calendar.ics");
  });

  test("подписанный на нынешний адрес не тревожится", () {
    expect(subscriptionIsStale(calendarFeedUrl), isFalse);
  });

  test("не подписывавшемуся не предлагают переподписаться", () {
    // Человек мог и не хотеть календаря вовсе; звать его переподписаться на то,
    // чего он не заводил, — навязчивость.
    expect(subscriptionIsStale(null), isFalse);
    expect(subscriptionIsStale(""), isFalse);
  });

  test("признак — расхождение адресов, а не дата переезда", () {
    // Дата в коде означала бы правку в день переезда и ещё одну — когда старый
    // домен погаснет. Расхождение же само становится верным ровно тогда, когда
    // сменится siteHost.
    expect(subscriptionIsStale("https://example.org/calendar.ics"), isTrue);
  });
}
