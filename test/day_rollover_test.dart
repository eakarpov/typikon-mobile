import 'package:flutter_test/flutter_test.dart';
import 'package:typikon/utils/day_rollover.dart';

void main() {
  final evening = DateTime(2026, 9, 19, 22, 30);
  final morning = DateTime(2026, 9, 20, 7, 0);

  test("смотрел сегодня, наступило завтра — переводим", () {
    expect(
      dateAfterResume(selected: evening, lastSeenToday: evening, now: morning),
      morning,
    );
  });

  test("день тот же — ничего не трогаем", () {
    expect(
      dateAfterResume(
        selected: evening,
        lastSeenToday: evening,
        now: DateTime(2026, 9, 19, 23, 59),
      ),
      isNull,
    );
  });

  test("листал другой день — его и оставляем", () {
    // Иначе приготовленное с вечера чтение на праздник наутро сбрасывалось бы.
    expect(
      dateAfterResume(
        selected: DateTime(2026, 9, 27),
        lastSeenToday: evening,
        now: morning,
      ),
      isNull,
    );
  });
}
