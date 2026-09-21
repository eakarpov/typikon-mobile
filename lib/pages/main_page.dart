import 'package:typikon/apiMapper/version.dart';
import 'package:typikon/dto/version.dart';
import 'package:typikon/version.dart';
import 'package:typikon/utils/app_version.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../components/api_error_view.dart' show isNetworkError;
import "../dto/text.dart";
import "../apiMapper/common.dart";
import "../dto/common.dart";
import '../dto/calendar.dart';
import "../components/day_memories.dart";
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/models/models.dart';
import '../utils/day_preloader.dart';
import '../utils/selected_day.dart';
import '../components/trapeza_line.dart';
import '../utils/bible_route.dart';
import '../utils/route_observer.dart';
import 'menu_entries.dart';

const String APP_STATE_KEY = "APP_STATE";

/// Пункты раздела, видимые сейчас.
///
/// Личные разделы без учётной записи не прячутся из вежливости: заметок,
/// помянника и поданных записок у невошедшего нет вовсе, и открытый пустой
/// экран читался бы как поломка.
List<MenuEntry> _visibleEntries(BuildContext context, MenuSection section) {
  final signedIn = StoreProvider.of<AppState>(context).state.auth.isSignedIn;
  return section.entries
      .where((entry) =>
          entry.visibility == MenuVisibility.always || signedIn)
      .toList();
}

class MainPage extends StatefulWidget {
  const MainPage(context, {
    super.key,
    required this.hasSkippedUpdate,
    required this.skipUpdateWindow,
  });

  final bool hasSkippedUpdate;
  final ValueChanged<bool> skipUpdateWindow;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin, RouteAware, WidgetsBindingObserver, SelectedDay {
  late Future<MainPageData> data;
  late Future<Version> version;

  /// Что ответил сервер. Нужен ящику: пункт «Обновить приложение» показывается
  /// тому, кто предложение пропустил, — а адрес выпуска называет сервер, и до
  /// ответа его взять неоткуда.
  Version? _remote;

  // Предложение включить предзагрузку показываем один раз за жизнь страницы, а
  // снимаем в dispose: MaterialBanner живёт в ScaffoldMessenger выше
  // MaterialApp и иначе уехал бы на следующий экран вместе с пользователем.
  ScaffoldMessengerState? _messenger;
  bool _preloadBannerShown = false;
  bool _preloadBannerVisible = false;

  /// Тексты дня, о которых спрашивали. Держим, чтобы вернуть предложение, если
  /// читатель ушёл на другой экран, не ответив.
  List<String>? _preloadTextIds;

  @override
  void initState() {
    super.initState();
    version = getVersion();
    // Отказ проглатываем нарочно, и без него было бы хуже: результат этого
    // будущего никто, кроме здешнего `then`, не ждёт, а необработанная ошибка
    // асинхронного будущего уходит в обработчик верхнего уровня и попадает в
    // отчёт о падениях. Не узнать версию — обычное дело: сети нет, сервер занят,
    // ручка ещё не выложена. Молчать тут правильно: экран главной от версии не
    // зависит, и говорить читателю нечего.
    version.then((value) {
      // Экран мог закрыться, пока ходили за версией: showAlert стоял вне
      // проверки и показывал окно поверх уже снятого дерева.
      if (!mounted) return;
      setState(() => _remote = value);
      if (isUpdateAvailable(value) && !widget.hasSkippedUpdate) {
        showAlert(context, value);
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    if (_preloadBannerVisible) _messenger?.hideCurrentMaterialBanner();
    super.dispose();
  }

  /// Поверх главной положили другой экран.
  ///
  /// Баннер снимаем: он живёт в `ScaffoldMessenger` выше `MaterialApp` и иначе
  /// поедет с читателем в Библию, в калькулятор и куда угодно ещё.
  @override
  void didPushNext() => _hidePreloadBanner();

  /// Вернулись на главную. Если так и не ответили — спрашиваем снова: вопрос
  /// один и тот же, и молча забыть его значило бы никогда не включить
  /// предзагрузку тому, кто в тот раз просто пролистал мимо.
  @override
  void didPopNext() {
    if (!mounted) return;
    final ids = _preloadTextIds;
    if (ids == null) return;
    if (!StoreProvider.of<AppState>(context).state.settings.shouldAskAboutPreload) return;
    _showPreloadBanner(ids);
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  /// Как главная грузит свой день — остальное (когда и по какому поводу) знает
  /// примесь SelectedDay.
  @override
  void loadDay(DateTime day) {
    data = _loadDay(SelectedDay.keyOf(day));
  }

  /// Загружает день и, если пользователь на это согласился, следом тихо
  /// докачивает его тексты, чтобы они открылись и без сети. Ошибки
  /// предзагрузки страницы не касаются.
  Future<MainPageData> _loadDay(String date) {
    final future = updateData(date);
    future.then((value) {
      final day = value.day;
      if (day == null || !mounted) return;

      final settings = StoreProvider.of<AppState>(context).state.settings;
      if (settings.isPreloadEnabled) {
        unawaited(preloadTexts(day.textIds));
        return;
      }
      // Спрашиваем не на пустом экране, а когда день уже показан: так понятно,
      // о каких именно чтениях речь.
      _preloadTextIds = day.textIds;
      if (settings.shouldAskAboutPreload && !_preloadBannerShown) {
        _preloadBannerShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showPreloadBanner(day.textIds);
        });
      }
    }).catchError((_) {});
    return future;
  }

  void _hidePreloadBanner() {
    if (!_preloadBannerVisible) return;
    _preloadBannerVisible = false;
    _messenger?.hideCurrentMaterialBanner();
  }

  void _answerPreload(bool enabled, List<String> textIds) {
    _preloadTextIds = null;
    _hidePreloadBanner();
    StoreProvider.of<AppState>(context).dispatch(ChangePreloadTextsAction(enabled));
    if (enabled) unawaited(preloadTexts(textIds));
  }

  void _showPreloadBanner(List<String> textIds) {
    _preloadBannerVisible = true;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text(
          "Скачивать чтения дня заранее, чтобы читать их в храме без сети? "
          "Это расходует мобильный трафик; переключить можно в настройках.",
        ),
        actions: [
          TextButton(
            onPressed: () => _answerPreload(false, textIds),
            child: const Text("Не нужно"),
          ),
          TextButton(
            onPressed: () => _answerPreload(true, textIds),
            child: const Text("Скачивать"),
          ),
        ],
      ),
    );
  }

  void onLoadUpdate(BuildContext context, Version remote) async {
    Navigator.of(context).pop();
    final Uri url = Uri.parse(updateUrl(remote));
    if (await canLaunchUrl(url)) {
      await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: "_blank",
      );
    } else {
      throw new Exception("Cannot launch update");
    }
  }

  void onSkipUpdate(BuildContext context) async {
    widget.skipUpdateWindow(true);
    Navigator.of(context).pop();
  }

  void showAlert(BuildContext context, Version value) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Обновление'),
          content: Text('Появилось новое обновление: Версия $value'),
          actions: <Widget>[
            TextButton(
              onPressed: () => onSkipUpdate(context),
              child: const Text('Пропустить'),
            ),
            TextButton(
              onPressed: () => onLoadUpdate(context, value),
              child: const Text('Загрузить'),
            ),
          ],
    ));
  }

  void onGoToLibrary() {
    Navigator.pushNamed(context, "/library");
  }

  void onGoToCalculator() {
    Navigator.pushNamed(context, "/calculator");
  }

  /// Куда ведёт строка дневного чтения.
  ///
  /// `null` — вести некуда, и тогда строка не нажимается вовсе. Это не редкость:
  /// зачало без книги канона приезжает из дневных ответов, что лежат в кэше
  /// сутками, а вести его в текст нельзя — идентификатор зачала указывает на
  /// книгу Библии, которой в коллекции текстов больше нет.
  VoidCallback? _openItem(BuildContext context, CalendarDayPartItem item) {
    if (item.isPericope) {
      if (item.bookSlug == null || item.ranges.isEmpty) return null;
      return () => Navigator.pushNamed(
            context,
            "/bible",
            arguments: bibleRouteArgument(
              item.bookSlug!,
              chapter: item.ranges.first.chapterFrom,
              ranges: item.ranges,
            ),
          );
    }

    final id = item.id;
    if (id == null) return null;
    return () => Navigator.pushNamed(context, "/reading", arguments: id);
  }

  Widget renderItem(BuildContext context, List<CalendarDayPartItem> list, String title) {
    const titleStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      color:  Colors.red,
    );
    return Column(
          children: [
            Text(title, style: titleStyle),
            Container(
              child: ListView.builder(
                shrinkWrap: true,
                scrollDirection: Axis.vertical,
                itemCount: list.length,
                physics: new NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Container(
                    child: ListTile(
                      title: Text(
                        item.name,
                        style: TextStyle(fontFamily: "OldStandard", color: Colors.red),
                      ),
                      // Зачало ведёт в раздел Библии, обычное чтение — в текст.
                      // Прежде и то и другое шло в "/reading", и для зачал это
                      // был путь в пустой ответ: их идентификатор указывает на
                      // книгу Библии, которой в коллекции текстов больше нет.
                      onTap: _openItem(context, item),
                    ),
                  );
                },
              ),
            ),
          ],
    );
  }

  @override
  Widget build(BuildContext context) {
    DateFormat format = DateFormat("dd.MM.yyyy");
    // String value = _selectedDate.isRegistered ? format.format(_selectedDate.value) : "Не задано";
    String value = format.format(selectedDay);
    return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
                value,
                style: TextStyle(fontFamily: "OldStandard")
            ),
            actions: <Widget>[
              IconButton(
                tooltip: "Выбрать дату",
                icon: Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                ),
                onPressed: () {
                  pickDay();
                  // _restorableDatePickerRouteFuture.present();
                },
              )
            ],
            bottom: TabBar(
              tabs: [
                Tab(child: Icon(Icons.list)),
                Tab(child: Icon(Icons.update)),
                Tab(child: Icon(Icons.info_outline)),
              ],
            ),
          ),
          bottomNavigationBar: new BottomNavigationBar(
              currentIndex: 0,
              onTap: (int _index) {
                if (_index == 0) { // День назад
                  goToDay(selectedDay.subtract(const Duration(days: 1)));
                } else if (_index == 1) { // День вперед
                  goToDay(selectedDay.add(const Duration(days: 1)));
                }
              },
              items: <BottomNavigationBarItem>[
                new BottomNavigationBarItem(
                  icon: new Icon(Icons.arrow_left),
                  label: "День назад",
                ),
                new BottomNavigationBarItem(
                  icon: new Icon(Icons.arrow_right),
                  label: "День вперед",
                ),
              ]),
          body: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: FutureBuilder(
              future: data,
              builder: (context, future) {
                // Сверяем и состояние, а не одно `hasData`: FutureBuilder при
                // смене будущего держит прежние данные, и после «День вперёд»
                // под новой датой стояли бы чтения вчерашнего дня.
                if (future.connectionState == ConnectionState.done && future.hasData) {
                  CalendarDay? calendarDay = future.data?.day;
                  // Может не прийти: отказ этого списка главную больше не
                  // гасит (см. apiMapper/common.dart).
                  final ReadingList? list2 = future.data?.lastTexts;

                return TabBarView(
                  children: [
                  SingleChildScrollView(
                    child: Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 12.0),
                            child: Text(
                              "Добро пожаловать",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text("В данный момент доступна библиотека книг и текстов, подборка чтений по дням Цветной Триоди, "
                              "календарные чтения на каждый день года, поиск по названию текста, "
                              "а также просмотр памятей на день. Ждите новых обновлений!", textAlign: TextAlign.justify,),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onGoToCalculator,
                      child: Text("Собранные чтения дня наряду"),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text(
                        "Чтения на выбранную дату: ${calendarDay?.name}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Строка о трапезе идёт своим запросом и никогда не
                    // задерживает чтения: за ней стоит служба устава, отвечающая
                    // до восьми секунд. Пока её нет — на её месте ничего нет.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: TrapezaLine(
                        date: StoreProvider.of<AppState>(context).state.common.date,
                      ),
                    ),
                    if (calendarDay != null) Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.0),
                      child: DayMemoriesView(memories: calendarDay.memories),
                    ),
                    // Места службы приходят с сервера — списком, с готовыми
                    // подписями и в порядке хода службы. Прежде здесь стоял
                    // двадцать один повтор с зашитыми названиями: третья копия
                    // того же перечня в приложении. Две первые уже однажды
                    // разошлись, и Великий пяток потерял два чтения.
                    ...?calendarDay?.readings.map((section) =>
                        renderItem(context, section.items, section.title)),
                  ],
                  ),
                  ),
                  Column(
                    children: [
                      Text("Последние добавленные тексты", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Container(
                        child: ListView.builder(
                          shrinkWrap: true,
                          scrollDirection: Axis.vertical,
                          physics: new NeverScrollableScrollPhysics(),
                          itemCount: list2?.list.length ?? 0,
                          itemBuilder: (context, index) {
                            final item = list2!.list[index];
                            return Container(
                              child: ListTile(
                                title: Text(item.name, style: TextStyle(fontFamily: "OldStandard", color: Colors.red),),
                                subtitle: Text(
                                    "Обновлено ${item.updatedAt.day}.${item.updatedAt.month}.${item.updatedAt.year}"),
                                onTap: () => {
                                  Navigator.pushNamed(context, "/reading", arguments: item.id)
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          Text("Цель и обоснование проекта", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("Цель проекта заключается в собрании церковнославянского корпуса текстов уставных чтений и создании его последования, основываясь на Типиконе.", textAlign: TextAlign.justify),
                          Text("Большая часть текстов отекстована в русском переводе и доступна для поиска. Тем не менее, даже в русскоязычном варианте не дается представления о том, что предлагает Типикон для чтения верующих в тот или иной день церковного года. В рамках данного проекта производится работа по отекстовке корпуса уставных чтений, соотнесение их с чтением в определенный день церковного года и сопоставление с корпусом русских текстов уставных чтений.", textAlign: TextAlign.justify),
                          Text("Что такое уставные чтения?", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("Уставные чтения — сборники нравоучительно-повествовательного характера, состоящие в основном из произведений дидактического и тор жественного красноречия, агиографических сочинений, а также полемических слов, толкований, кратких нравоучительных сентенций.", textAlign: TextAlign.justify),
                          Text("О предмете уставных чтений", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("протопресвитер Василий Виноградов", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("В богатом содержанием современном Церковном Уставе скромно затерялось одно совершенно неприметное, по своей внешней бесцветности и нехарактерности, выражение, в отношении которого даже самый добросовестный рядовой читатель считает вполне для себя дозволительным не останавливать своего внимания, как на подробности слишком мелкой и слишком малозначительной."),
                          Text("Это выражение состоит из одного слова, скромно вплетающегося в непрерывную цепь уставных указаний при помощи соединительного союза «и»: «и чтение». Но лаконически краткое и маловыразительное, оно неотступно преследует внимательного читателя «Устава» страница за страницей, встречает его глаз непременно в одних и тех же местах церковно-богослужебного последования: на утрене – после каждой кафизмы, на полиелее, после 3-ей и 6-ой песен канона, по отпуске пред первым часом, – и на всенощном бдении по окончании вечерни пред началом утрени."),
                          Text("«Чтение... чтение... чтение»…", textAlign: TextAlign.justify),
                          Text("Что это за «чтение?» Большинство читателей Устава, читателей «ех officio», успокаивается на мысли, что здесь, разумеется, вообще какое-то, обычно непрактикуемое теперь, дополнительное чтение, в роде чтения псалтири или седальнов. Но при более внимательном ознакомлении с Уставом замечается, что лаконическое указание «чтение» по временам принимает более конкретный и определенный характер: «и чтение... чтется от слова иже во святых отца нашего... чтется от жития святого... от словес торжественных... слово Златоуста... слово Богослова... чтется от шестодневника Св. Василия Великого, чтется от толкований на Евангелие, на послание Павла апостола, оглашение преп. отца нашего Феодора Студита» и т. д. Отсюда для внимательного читателя «Устава» естественно следует приблизительно правильное общее представление о церковно-богослужебном факте, кроющемся под уставным термином «чтение»; это есть теперь уже обычно непрактикующееся чтение в определенные моменты богослужения церковно-учительных произведений, преимущественно житий святых и святоотеческих творений.", textAlign: TextAlign.justify),
                          Text("Обычно думают, что Уставные Чтения это – одно из таких же мало выдающихся явлений исторической жизни Руси, как чтение псалтири или канонов за богослужением, как исследование об Уставных Чтениях понимается, как исследование одного узкоспециального археологически-литургического интереса с исследованиями о порядке чтения псалтири или канонов в русском богослужении давно минувшего времени. Иначе говоря, думают, что Уставные Чтения могут представлять интерес только со стороны своего литургического положения, как мелкий литургический факт, не допуская и мысли, чтобы это мог быть факт более высокой научной ценности и более широкого значения.", textAlign: TextAlign.justify),
                          Text("А между тем Уставные Чтения – чрезвычайно важный факт в исторической жизни древней Руси.", textAlign: TextAlign.justify),
                          Text("Об этом говорит уже простое сопоставление установленных наукой общих положений о характере идейной жизни древней Руси с указанным сейчас общим понятием об Уставных Чтениях как чтениях из церковно-учительных произведений, производившихся в древней Руси за богослужением.", textAlign: TextAlign.justify),
                          Text("А. «В наше время, – писал проф. Иконников в 1869 г., – книга получила могущественное влияние и не редко заменяет школу, но в доброе старое время школа давала умственное направление обществу, и только отдельные умы, создавая новое, разрывали заветные связи со школою, из которой они вышли. Но в древней Руси школьное обучение имело узкий объем, ограничиваясь научением чтению по часослову и псалтири и письму, единственной же школой, где русское общество могло получать идейное поучение, была церковь – храм: а среди всех средств, которыми храм поучал общество, самым непосредственным и понятным средством, конечно, были Уставные Чтения. Отсюда вытекает вопрос о значении Уставных Чтений, как первостепенной силы, дававшей направление идейной жизни общества.", textAlign: TextAlign.justify),
                          Text("Б. «В строгом смысле слова, до XVII века у нас не было науки. Наша литературная деятельность до того времени верно характеризуется названием книжности. Она стояла в самом тесном отношении к религии и была ее результатом; книжность должна была удовлетворять только религиозным потребностям». Но если древнерусская литературная деятельность стояла в самом тесном отношении к религии, как ее результат, то, конечно, она не могла не стоять в таком же отношении и к тем письменным произведениям, которые, выражая сущность этой религии, читались вслух всего церковного общества и при том в самом сердце религиозной жизни, в учреждении самого высшего религиозного авторитета, – в храме. А отсюда вытекает новый вопрос: об Уставных Чтениях как важнейшем источнике и вместе продукте древнерусской литературной деятельности.", textAlign: TextAlign.justify),
                          Text("«Книжность в России распространялась главным образом чрез монастыри, и потому русская образованность древней эпохи может быть вполне названа монастырской». Но так как в монастырях вся жизнедеятельность имела сосредоточие в храме, в богослужении, то естественно, чтобы и образованность монастырская по своему характеру и идейному содержанию стояла в самой тесной зависимости от идейного содержания тех поучительных произведений, которые читались за богослужением в руководство всей братии, т. е. с Уставными Чтениями.", textAlign: TextAlign.justify),
                        ],
                      ),
                    ),
                  ),
                ],
                );
               } else if (future.connectionState == ConnectionState.done && future.hasError) {
                  return Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Не текст исключения: «ClientException with
                              // SocketException: Failed host lookup» на главном
                              // экране выглядит поломкой приложения, хотя это
                              // пропавшая сеть. Найдено на устройстве в режиме
                              // полёта — в коде это место читалось безобидно.
                              Icon(
                                isNetworkError(future.error) ? Icons.wifi_off : Icons.error_outline,
                                size: 48.0,
                              ),
                              const SizedBox(height: 16.0),
                              Text(
                                isNetworkError(future.error)
                                    ? "Нет соединения с интернетом."
                                    : "Не удалось загрузить чтения дня.",
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: reloadSelectedDay,
                          child: Text("Повторить"),
                        ),
                      ],
                    ),
                  );
                }
                return Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                    ],
                  ),
                );
              }
            ),
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).appBarTheme.backgroundColor,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Типикон ($majorVersion.$minorVersion.0)'),
                      // IconButton, а не GestureDetector поверх иконки: у того
                      // зона нажатия ровно по глифу (24 точки при положенных 48)
                      // и нет ни отклика на нажатие, ни имени для чтеца экрана.
                      IconButton(
                        tooltip: "Поиск",
                        onPressed: () {
                          Navigator.pushNamed(context, "/search");
                        },
                        icon: Icon(
                          Icons.search,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Меню строится из описи lib/pages/menu_entries.dart: двадцать
                // пять одинаковых ListTile подряд разъезжались с маршрутами и
                // росли с каждым разделом. Одиннадцать пунктов ушли под
                // «Собрание» и «Пособия».
                for (final section in drawerSections) ...[
                  if (_visibleEntries(context, section).isNotEmpty) ...[
                    if (section.title != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
                        child: Text(
                          section.title!,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    for (final entry in _visibleEntries(context, section))
                      ListTile(
                        title: Text(entry.title, style: const TextStyle(fontSize: 14.0)),
                        selected: ModalRoute.of(context)?.settings.name == entry.route,
                        onTap: () {
                          Navigator.pushNamed(context, entry.route);
                        },
                      ),
                    const Divider(height: 1),
                  ],
                ],
                ListTile(
                  title: const Text('Помочь проекту', style: TextStyle(fontSize: 14.0),),
                  onTap: () {
                    String url = dotenv.env['CLOUDTIPS_URL'] ?? "";
                    Uri myUrl = Uri.parse(url);
                    launchUrl(myUrl);
                  },
                ),
                if (widget.hasSkippedUpdate) ListTile(
                  title: const Text("Обновить приложение", style: TextStyle(fontSize: 14.0),),
                  // До ответа сервера адрес выпуска берётся прежний, свой:
                  // ждать ответа, чтобы дать нажать кнопку, незачем.
                  onTap: () => onLoadUpdate(context, _remote ?? const Version(major: 0, minor: 0)),
                ),
              ],
             ),
            ),
          ),
        );
  }
}