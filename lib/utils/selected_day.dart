import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';

import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/utils/day_rollover.dart';

/// Экран, который показывает выбранный день.
///
/// Таких три — главная, калькулятор и памяти дня, — и день у них общий:
/// `common.date` в сторе. До этого общим он был только на словах. Окно выбора
/// даты стояло в каждом своей копией (одни и те же `firstDate`, `lastDate`,
/// локаль и три закомментированных довода), сверка «а не тот же ли это день»
/// была написана дважды по-разному, а переход через полночь знала одна главная:
/// калькулятор, оставленный открытым на ночь, наутро по-прежнему считал вчера.
///
/// Страница обязана лишь сказать, как она грузит свой день ([loadDay]).
/// Остальное — когда перезагружать, что показывать в заголовке, как спросить
/// дату и что делать при смене суток — здесь.
mixin SelectedDay<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  /// День, на который уже загружено. Сверяется, чтобы не грузить одно и то же:
  /// `didChangeDependencies` зовётся на каждый экран, положенный поверх и
  /// снятый, и без сверки возврат из текста стоил бы запроса и потерянного
  /// места в списке.
  String? _loadedDayKey;

  /// Какой день был сегодняшним, когда на приложение смотрели в прошлый раз.
  DateTime _lastSeenToday = DateTime.now();

  /// Загрузить данные на этот день. Зовётся уже внутри `setState`, если нужно.
  void loadDay(DateTime day);

  /// Выбранный день. `listen: false` — на перерисовку подписываться незачем:
  /// смену дня страница замечает сама, через [syncSelectedDay] и [goToDay].
  DateTime get selectedDay =>
      StoreProvider.of<AppState>(context, listen: false).state.common.date;

  /// День строкой, как его ждёт вторая версия API.
  static String keyOf(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncSelectedDay();
  }

  /// Догрузить, если день в сторе разошёлся с показанным.
  void syncSelectedDay() {
    final day = selectedDay;
    final key = keyOf(day);
    if (key == _loadedDayKey) return;
    _loadedDayKey = key;
    loadDay(day);
  }

  /// Перейти на другой день: запомнить выбор и перезагрузить.
  ///
  /// Через `setState` нарочно: без него новый день показывался лишь потому, что
  /// закрытие окна выбора дёргало `didChangeDependencies`, — то есть случайно.
  void goToDay(DateTime day) {
    StoreProvider.of<AppState>(context, listen: false)
        .dispatch(ChangeCommonDateAction(day));
    _loadedDayKey = keyOf(day);
    setState(() => loadDay(day));
  }

  /// Перезагрузить нынешний день — для «Повторить» и жеста обновления.
  void reloadSelectedDay() => setState(() => loadDay(selectedDay));

  /// Спросить дату у человека.
  Future<void> pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale("ru", "RU"),
      initialDate: selectedDay,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialEntryMode: DatePickerEntryMode.calendar,
      initialDatePickerMode: DatePickerMode.day,
    );
    if (!mounted || picked == null || picked == selectedDay) return;
    goToDay(picked);
  }

  /// Наступил новый день, пока приложение лежало в памяти.
  ///
  /// Правило — в `utils/day_rollover.dart`: переводим только того, кто смотрел
  /// «сегодня», иначе приготовленное с вечера чтение на праздник наутро
  /// сбрасывалось бы.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed || !mounted) return;

    final now = DateTime.now();
    final next = dateAfterResume(
      selected: selectedDay,
      lastSeenToday: _lastSeenToday,
      now: now,
    );
    _lastSeenToday = now;
    if (next != null) goToDay(next);
  }
}
