import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import "package:flutter_colorpicker/flutter_colorpicker.dart";
import 'dart:ui';

import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/api/cached_fetch.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:typikon/components/api_error_view.dart';
import 'package:typikon/components/calendar_subscription.dart';
import 'package:typikon/apiMapper/auth.dart' as auth_api;
import 'package:typikon/store/pomyannik_cache.dart';
import 'package:typikon/store/store.dart';
import 'package:typikon/utils/pomyannik_reminders.dart';
import 'package:typikon/utils/reading_schemes.dart';
import 'package:typikon/utils/push.dart';
import 'package:typikon/store/calendar_feed.dart';
import 'package:typikon/store/day_reading_notice.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage(context, {super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

typedef OnFontSizeChange = Function(int fontSize);

class _SettingsPageState extends State<SettingsPage> {
  /// Размер под пальцем, пока ползунок не отпущен.
  double? _draftFontSize;

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
    _loadSubscription();
    _loadReadingHour();
  }

  void onPress() {
    StoreProvider.of<AppState>(context).dispatch(ChangeFontSizeAction(StoreProvider.of<AppState>(context).state.settings.fontSize + 1));
  }

  void onClearCache(BuildContext context) async {
    await clearHttpCache();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Кэш очищен")),
    );
  }

  bool _authInProgress = false;

  // Обычными ключами хранилища, а не полем состояния: их читает фоновая задача,
  // а она живёт в отдельном изоляте, где хранилища состояния нет вовсе.
  bool _reminders = false;
  bool _namesInReminders = false;

  /// Ключ доставки берётся с задержкой: пока идёт, кнопки заперты, иначе два
  /// нажатия подряд завели бы два разных устройства.
  bool _switchingSource = false;

  /// Подписан ли человек на прежний адрес ленты.
  bool _staleSubscription = false;

  /// Час, в который человек просил говорить о чтениях; `null` — не просил.
  int? _readingHour;

  Future<void> _loadReadingHour() async {
    final hour = await dayReadingHour();
    if (!mounted) return;
    setState(() => _readingHour = hour);
  }

  Future<void> _onReadingHour(int? hour) async {
    setState(() => _readingHour = hour);
    await setDayReadingHour(hour);
    // Час знает и сервер — он шлёт толчок именно в него. Перепривязка отдаёт
    // ему новый; без неё точные уведомления приходили бы в прежний час до
    // следующего запуска приложения.
    await refreshPushRegistration(
        wanted: appStore?.state.settings.remindsFromServer ?? false);
  }

  Future<void> _loadSubscription() async {
    final stale = subscriptionIsStale(await subscribedCalendarUrl());
    if (!mounted) return;
    setState(() => _staleSubscription = stale);
  }

  Future<void> _loadReminderSettings() async {
    final reminders = await remindersEnabled();
    final names = await namesInReminders();
    if (!mounted) return;
    setState(() {
      _reminders = reminders;
      _namesInReminders = names;
    });
  }

  Future<void> _onReminders(bool value) async {
    setState(() => _reminders = value);
    await setRemindersEnabled(value);
    if (!value) return;
    // Включили — сразу и собираем зеркало, иначе первое напоминание пришло бы
    // только после следующего открытия помянника.
    await refreshPomyannikMirror(appStore?.state.auth.userId);
  }

  /// Кто будит: приложение или сервер.
  ///
  /// Выбрав сервер, надо тут же отдать ему ключ доставки — иначе настройка
  /// стояла бы «сервер», а стучаться было бы некуда. Не вышло (отказали в
  /// разрешении, нет сети, не поднялся Firebase) — честно возвращаемся к
  /// приложению и говорим об этом: молчаливая настройка, которая не работает,
  /// хуже отсутствующей.
  Future<void> _onReminderSource(String value) async {
    if (value == "server") {
      setState(() => _switchingSource = true);
      final ok = await enablePush();
      if (!mounted) return;
      setState(() => _switchingSource = false);

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Не вышло включить толчки: нужны разрешение на "
              "уведомления и сеть. Напоминания остаются за приложением."),
        ));
        return;
      }
    } else {
      await disablePush();
    }

    appStore?.dispatch(ChangeReminderSourceAction(value));
  }

  Future<void> _onNamesInReminders(bool value) async {
    setState(() => _namesInReminders = value);
    // Выключение действует назад: имена стираются и из уже записанного зеркала.
    await setNamesInReminders(value);
    if (value) await refreshPomyannikMirror(appStore?.state.auth.userId);
  }

  void onSignIn(BuildContext context) async {
    if (_authInProgress) return;
    setState(() { _authInProgress = true; });
    try {
      await auth_api.signInWithGoogle(StoreProvider.of<AppState>(context));
    } on GoogleSignInException catch (e) {
      // Закрыл окно входа — это не неудача, и сообщать о ней незачем.
      if (e.code != GoogleSignInExceptionCode.canceled && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Не удалось войти через Google")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Не текст исключения: см. failureMessage.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(e, "войти не удалось"))),
        );
      }
    } finally {
      if (mounted) setState(() { _authInProgress = false; });
    }
  }

  void onSignOut(BuildContext context) async {
    if (_authInProgress) return;
    setState(() { _authInProgress = true; });
    try {
      await auth_api.signOut(StoreProvider.of<AppState>(context));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(e, "выйти не удалось"))),
        );
      }
    } finally {
      if (mounted) setState(() { _authInProgress = false; });
    }
  }

  void onOpenPicker(BuildContext context, Color value, void Function(Color) cb) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Выберите цвет'),
        content: SingleChildScrollView(
          child: MaterialPicker(
            pickerColor: value,
            onColorChanged: cb,
          ),
        ),
        actions: [
          Builder(
            builder: (dialogContext) => TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Готово"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Настройки", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: StoreConnector<AppState, SettingsViewModel>(
        converter: (store) => SettingsViewModel.build(store),
        builder: (context, viewModel) {
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 20, left: 16, right: 16),
                    child: Text("Тема оформления", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text("Системная")),
                        ButtonSegment(value: ThemeMode.light, label: Text("Светлая")),
                        ButtonSegment(value: ThemeMode.dark, label: Text("Тёмная")),
                      ],
                      selected: {viewModel.themeMode},
                      onSelectionChanged: (selected) {
                        viewModel.onChangeThemeMode(selected.first);
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 20, left: 16),
                    child: Text("Размер текста чтений", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Slider(
                      // Пока палец на ползунке, размер живёт здесь, а в стор
                      // уходит по отпусканию: иначе каждое деление перестраивало
                      // всё приложение и переписывало настройки на диске.
                      value: (_draftFontSize ?? viewModel.fontSize.toDouble())
                          .clamp(minFontSize.toDouble(), maxFontSize.toDouble()),
                      onChanged: (newValue) => setState(() => _draftFontSize = newValue),
                      onChangeEnd: (newValue) {
                        viewModel.onChangeFontSize(newValue.round());
                        setState(() => _draftFontSize = null);
                      },
                      min: minFontSize.toDouble(),
                      max: maxFontSize.toDouble(),
                      divisions: maxFontSize - minFontSize,
                      label: "${(_draftFontSize ?? viewModel.fontSize.toDouble()).round()}",
                    ),
                  ),
                  _Choices<double>(
                    title: "Междустрочный интервал",
                    hint: "Церковнославянский набор несёт ударения и титла: при "
                        "тесных строках они сливаются со строкой над собой.",
                    value: viewModel.lineHeight,
                    onPicked: viewModel.onChangeLineHeight,
                    // Не `const`: `double` переопределяет `==`, и константной
                    // картой такие ключи Dart не берёт.
                    options: <double, String>{
                      1.35: "Плотно",
                      1.5: "Обычно",
                      1.8: "Просторно",
                      2.1: "Очень просторно",
                    },
                  ),
                  _Choices<String>(
                    title: "Выключка",
                    hint: "Переносов у нас нет, и выключка по ширине местами "
                        "разгоняет пробелы.",
                    value: viewModel.readingAlign,
                    onPicked: viewModel.onChangeReadingAlign,
                    options: const {
                      "justify": "По ширине",
                      "left": "По левому краю",
                    },
                  ),
                  _Choices<double?>(
                    title: "Ширина колонки",
                    hint: "На телефоне разницы нет: строка и так узкая. "
                        "На планшете и в развороте — есть.",
                    value: viewModel.readingMeasure,
                    onPicked: viewModel.onChangeReadingMeasure,
                    options: <double?, String>{
                      544.0: "Узкая",
                      736.0: "Средняя",
                      960.0: "Широкая",
                      null: "Во всю ширину",
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 20, left: 16, right: 16),
                    child: Text("Цвета чтений", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  // Готовые пары, а не два пикера порознь: цвет фона и цвет
                  // текста осмысленны только вместе, и выбранные по отдельности
                  // они легко сходятся в нечитаемое — тёмный текст на тёмном.
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Wrap(
                      spacing: 8,
                      children: readingSchemes.map((scheme) {
                        final chosen = viewModel.backgroundColor == scheme.background &&
                            viewModel.fontColor == scheme.foreground;
                        return ChoiceChip(
                          selected: chosen,
                          onSelected: (_) {
                            viewModel.onChangeBackgroundColor(scheme.background);
                            viewModel.onChangeFontColor(scheme.foreground);
                          },
                          avatar: CircleAvatar(backgroundColor: scheme.background),
                          label: Text(scheme.label),
                        );
                      }).toList(),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.all(12),
                    color: viewModel.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
                    child: Text(
                      "Прему́дрость. Про́сти. Услы́шим свята́го Ева́нгелиа. "
                      "Мир всем. От Матфе́а свята́го Ева́нгелиа чте́ние.",
                      // Образец показывает и выключку, и интервал: иначе выбор
                      // делается вслепую и проверяется уходом в чтение.
                      textAlign: viewModel.readingAlign == "left"
                          ? TextAlign.left
                          : TextAlign.justify,
                      style: TextStyle(
                          fontFamily: "OldStandard",
                          fontSize: _draftFontSize ?? viewModel.fontSize.toDouble(),
                          height: viewModel.lineHeight,
                          color: viewModel.fontColor ?? Theme.of(context).textTheme.bodyLarge?.color
                      ),
                    ),
                  ),
                  Padding(
                      padding: EdgeInsets.only(top: 20, left: 16, right: 16),
                      child: TextButton(
                            child: Text("Выбрать цвет фона текстов", style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                             onOpenPicker(context, viewModel.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor, viewModel.onChangeBackgroundColor);
                            },
                      ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      child: Text("Выбрать цвет шрифта текстов", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        onOpenPicker(context, viewModel.fontColor ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black, viewModel.onChangeFontColor);
                      },
                    ),
                  ),
                  if (viewModel.backgroundColor != null || viewModel.fontColor != null) Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      child: Text("Сбросить цвета чтений (следовать теме)"),
                      onPressed: viewModel.onResetReadingColors,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      child: Text("Очистить кэш"),
                      onPressed: () => onClearCache(context),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 20, left: 16, right: 16),
                    child: Text("Чтение без сети", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    title: Text("Заранее скачивать чтения дня"),
                    subtitle: Text(
                      "Тексты дня загрузятся, пока есть связь, и откроются в храме без сети. "
                      "Расходует мобильный трафик.",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    value: viewModel.isPreloadEnabled,
                    onChanged: viewModel.onChangePreloadTexts,
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 20, left: 16, right: 16),
                    child: Text("Календарь", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  // Полоса о переезде — только тому, кто подписан на прежний
                  // адрес. Календарь забирает ленту сам и в приложение не
                  // заходит, поэтому иначе человек узнал бы о молчании ленты
                  // месяцы спустя, и не по ошибке, а по её отсутствию.
                  if (_staleSubscription) Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Адрес календаря изменился",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Вы подписаны на прежний адрес. Он ещё отвечает, но однажды "
                            "перестанет — и лента просто замолчит, без всякого "
                            "предупреждения. Подпишитесь заново, а старую подписку "
                            "удалите в своём календаре.",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              child: const Text("Подписаться заново"),
                              onPressed: () async {
                                await showCalendarSubscriptionSheet(context);
                                await _loadSubscription();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      child: Text("Подписаться на чтения в календаре"),
                      onPressed: () async {
                        await showCalendarSubscriptionSheet(context);
                        await _loadSubscription();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
                    child: Text("Чтения дня", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 2),
                    child: Text(
                      "Память и чтения дня одной строкой. Час выбираете вы: кто-то "
                      "читает до работы, кто-то накануне вечером, чтобы успеть на "
                      "вечерню.",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          selected: _readingHour == null,
                          onSelected: (_) => _onReadingHour(null),
                          label: const Text("Не говорить"),
                        ),
                        ...const [6, 7, 8, 9, 12, 18, 20].map((hour) => ChoiceChip(
                              selected: _readingHour == hour,
                              onSelected: (_) => _onReadingHour(hour),
                              label: Text("$hour:00"),
                            )),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 20, left: 16, right: 16),
                    child: Text("Аккаунт", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: viewModel.isSignedIn
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Вы вошли как ${viewModel.email ?? viewModel.name ?? 'пользователь Google'}"),
                              TextButton(
                                child: Text(_authInProgress ? "Выходим…" : "Выйти"),
                                onPressed: _authInProgress ? null : () => onSignOut(context),
                              ),
                            ],
                          )
                        : TextButton(
                            child: Text(_authInProgress ? "Входим…" : "Войти через Google"),
                            onPressed: _authInProgress ? null : () => onSignIn(context),
                          ),
                  ),
                  if (viewModel.isSignedIn) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Text("Напоминания помянника",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    SwitchListTile(
                      title: const Text("Напоминать о поминальных днях"),
                      subtitle: const Text(
                        "Утром того дня, когда он приходится. Напоминание может прийти позже "
                        "или не прийти вовсе: время выбирает система, а не приложение — "
                        "поэтому полагаться на него как на единственную память не стоит.",
                      ),
                      value: _reminders,
                      onChanged: _onReminders,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                      child: Text("Кто напоминает",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    // Различие названо словами, а не «обычные» и «точные»:
                    // выбор здесь не «лучше или хуже», а «всегда, но когда
                    // придётся» против «в минуту, но при сети».
                    RadioListTile<String>(
                      title: const Text("Приложение"),
                      subtitle: const Text(
                        "Работает и без сети, но время выбирает система: напоминание "
                        "может прийти позже или не прийти вовсе.",
                      ),
                      value: "device",
                      groupValue: viewModel.reminderSource,
                      onChanged: _reminders && !_switchingSource
                          ? (value) => _onReminderSource(value!)
                          : null,
                    ),
                    RadioListTile<String>(
                      title: const Text("Сервер"),
                      subtitle: const Text(
                        "Приходит утром в срок. Нужна сеть; не дойдёт, если приложение "
                        "остановлено через настройки системы. Имена при этом никуда не "
                        "отправляются: сервер лишь будит приложение, а что сказать, оно "
                        "решает само.",
                      ),
                      value: "server",
                      groupValue: viewModel.reminderSource,
                      onChanged: _reminders && !_switchingSource
                          ? (value) => _onReminderSource(value!)
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text("Показывать имена в уведомлении"),
                      subtitle: const Text(
                        "Пока выключено, уведомление говорит только, что день есть. Имена — "
                        "чужие, а уведомление видно на экране блокировки.",
                      ),
                      value: _namesInReminders,
                      onChanged: _reminders ? _onNamesInReminders : null,
                    ),
                  ],
                  SizedBox(height: 20),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}

class SettingsViewModel {
  final int fontSize;
  final Function(int) onChangeFontSize;

  final Color? backgroundColor;
  final Function(Color) onChangeBackgroundColor;

  final Color? fontColor;
  final Function(Color) onChangeFontColor;

  final ThemeMode themeMode;
  final Function(ThemeMode) onChangeThemeMode;

  final double lineHeight;
  final Function(double) onChangeLineHeight;

  final String readingAlign;
  final Function(String) onChangeReadingAlign;

  final double? readingMeasure;
  final Function(double?) onChangeReadingMeasure;

  final String reminderSource;

  final VoidCallback onResetReadingColors;

  final bool isPreloadEnabled;
  final Function(bool) onChangePreloadTexts;

  final bool isSignedIn;
  final String? email;
  final String? name;

  SettingsViewModel({
    this.fontSize = 0,
    this.onChangeFontSize = SettingsViewModel.stub,
    this.fontColor,
    this.onChangeFontColor = SettingsViewModel.stubColor,
    this.backgroundColor,
    this.onChangeBackgroundColor = SettingsViewModel.stubColor,
    this.themeMode = ThemeMode.system,
    this.onChangeThemeMode = SettingsViewModel.stubThemeMode,
    this.lineHeight = 1.5,
    this.onChangeLineHeight = SettingsViewModel.stubDouble,
    this.readingAlign = "justify",
    this.onChangeReadingAlign = SettingsViewModel.stubString,
    this.readingMeasure,
    this.onChangeReadingMeasure = SettingsViewModel.stubMeasure,
    this.reminderSource = "device",
    this.onResetReadingColors = SettingsViewModel.stubVoid,
    this.isPreloadEnabled = false,
    this.onChangePreloadTexts = SettingsViewModel.stubBool,
    this.isSignedIn = false,
    this.email,
    this.name,
  });

  static stub (int fontSize) {}

  static stubColor (Color backgroundColor) {}

  static stubThemeMode (ThemeMode themeMode) {}

  static stubVoid () {}

  static stubBool (bool value) {}

  static stubDouble (double value) {}

  static stubString (String value) {}

  static stubMeasure (double? value) {}

  static SettingsViewModel build(Store<AppState> store) {
    return SettingsViewModel(
      fontSize: store.state.settings.fontSize,
      onChangeFontSize: (newFontSize) {
        store.dispatch(ChangeFontSizeAction(newFontSize));
      },
      fontColor: store.state.settings.fontColor,
      onChangeFontColor: (newFontColor) {
        store.dispatch(ChangeFontColorAction(newFontColor));
      },
      backgroundColor: store.state.settings.backgroundColor,
      onChangeBackgroundColor: (newBackgroundColor) {
        store.dispatch(ChangeBackgroundColorAction(newBackgroundColor));
      },
      themeMode: store.state.settings.themeMode,
      onChangeThemeMode: (newThemeMode) {
        store.dispatch(ChangeThemeModeAction(newThemeMode));
      },
      lineHeight: store.state.settings.lineHeight,
      onChangeLineHeight: (value) {
        store.dispatch(ChangeLineHeightAction(value));
      },
      readingAlign: store.state.settings.readingAlign,
      onChangeReadingAlign: (value) {
        store.dispatch(ChangeReadingAlignAction(value));
      },
      readingMeasure: store.state.settings.readingMeasure,
      onChangeReadingMeasure: (value) {
        store.dispatch(ChangeReadingMeasureAction(value));
      },
      reminderSource: store.state.settings.reminderSource,
      onResetReadingColors: () {
        store.dispatch(ResetReadingColorsAction());
      },
      isPreloadEnabled: store.state.settings.isPreloadEnabled,
      onChangePreloadTexts: (value) {
        store.dispatch(ChangePreloadTextsAction(value));
      },
      isSignedIn: store.state.auth.isSignedIn,
      email: store.state.auth.email,
      name: store.state.auth.name,
    );
  }
}

typedef OnChangeFontSize = int;

/// Ряд взаимоисключающих значений одной настройки.
///
/// `Wrap` из фишек, а не `SegmentedButton`: у интервала четыре значения с
/// длинными подписями, и на узком экране сегменты вылезли бы за край.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.title,
    required this.value,
    required this.options,
    required this.onPicked,
    this.hint,
  });

  final String title;
  final String? hint;
  final T value;
  final Map<T, String> options;
  final void Function(T) onPicked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 2),
            child: Text(hint!, style: Theme.of(context).textTheme.bodySmall),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            spacing: 8,
            children: options.entries
                .map((option) => ChoiceChip(
                      selected: option.key == value,
                      onSelected: (_) => onPicked(option.key),
                      label: Text(option.value),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
