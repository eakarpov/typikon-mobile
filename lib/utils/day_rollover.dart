/// Наступил новый день, пока приложение лежало в памяти.
///
/// Дата в сторе ставится один раз, при запуске. Телефон, на котором приложение
/// не выгружают, наутро показывал вчерашние чтения под вчерашней датой — и
/// ничто на экране не говорило, что день уже другой.
///
/// Возвращает дату, на которую надо перейти, или `null`, если трогать нечего.
///
/// **Чужой выбор не трогаем.** Переводим только того, кто смотрел «сегодня»:
/// [selected] совпадает с днём, который был сегодняшним при прошлом взгляде
/// ([lastSeenToday]). Человек, листавший Страстную седмицу заранее, по
/// возвращении должен найти её же, а не сегодняшний вторник.
DateTime? dateAfterResume({
  required DateTime selected,
  required DateTime lastSeenToday,
  required DateTime now,
}) {
  if (_sameDay(lastSeenToday, now)) return null;
  if (!_sameDay(selected, lastSeenToday)) return null;
  return now;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
