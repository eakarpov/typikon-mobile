import 'package:typikon/apiMapper/version.dart';
import 'package:typikon/dto/version.dart';
import 'package:typikon/version.dart';
import 'package:url_launcher/url_launcher.dart';
import "package:google_fonts/google_fonts.dart";
import 'package:flutter_dotenv/flutter_dotenv.dart';

import "../dto/text.dart";
import "../apiMapper/reading.dart";
import '../apiMapper/calendar.dart';
import '../dto/calendar.dart';
import "../dto/day.dart";
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

class _MainPageState extends State<MainPage> with RestorationMixin {
  late Future<DayResult> currentDay;
  late Future<Version> version;
  late Future<ReadingList> lastTexts;

  @override
  String? get restorationId => "test";

  final RestorableDateTime _selectedDate = RestorableDateTime(DateTime.now());
  // late final RestorableRouteFuture<DateTime?> _restorableDatePickerRouteFuture =
  // RestorableRouteFuture<DateTime?>(
  //   onComplete: _selectDate,
  //   onPresent: (NavigatorState navigator, Object? arguments) {
  //     return navigator.restorablePush(
  //       _datePickerRoute,
  //       arguments: _selectedDate.value.millisecondsSinceEpoch,
  //     );
  //   },
  // );


  @override
  void initState() {
    super.initState();
    // currentDay = getCalendarDay(
    //     DateFormat('yyyy-MM-dd').format(
    //         // DateTime.now().subtract(const Duration(days: 13))
    //         DateTime.now()
    //     )
    // );
    currentDay = getCalendarReadingForDate(
        DateTime.now().subtract(const Duration(days: 13)).millisecondsSinceEpoch
        // DateFormat('yyyy-MM-dd').format(
        //     DateTime.now().subtract(const Duration(days: 13))
        // )
    );
    lastTexts = getLastTexts();
    version = getVersion();
    version.then((value) => {
      if ((value.major > majorVersion || value.minor > minorVersion) && !widget.hasSkippedUpdate) {
        showAlert(context, value)
      }
    });
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_selectedDate, 'selected_date');
    // registerForRestoration(
    //     _restorableDatePickerRouteFuture, 'date_picker_route_future');
  }

  // static Route<DateTime> _datePickerRoute(BuildContext context, Object? arguments) {
  //   return DialogRoute<DateTime>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       // return showDatePicker(
  //       //     context: context,
  //       //     initialDate: DateTime.fromMillisecondsSinceEpoch(arguments! as int),
  //       //     firstDate: DateTime(1970),
  //       //     lastDate: DateTime(2026));
  //       // );
  //       return DatePickerDialog(
  //         cancelText: "Отменить",
  //         confirmText: "Выбрать",
  //         helpText: "Выбрать дату",
  //         // locale: const Locale("fr", "FR"),
  //         restorationId: 'date_picker_dialog',
  //         initialEntryMode: DatePickerEntryMode.calendarOnly,
  //         initialDate: DateTime.fromMillisecondsSinceEpoch(arguments! as int),
  //         firstDate: DateTime(1970),
  //         lastDate: DateTime(2026),
  //       );
  //     },
  //   );
  // }

  void buildMaterialDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      locale: const Locale("ru", "RU"),
      initialDate: DateTime.fromMillisecondsSinceEpoch(_selectedDate.value.millisecondsSinceEpoch! as int),
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
      initialEntryMode: DatePickerEntryMode.calendar,
      initialDatePickerMode: DatePickerMode.day,
      // helpText: 'Select booking date',
      // cancelText: 'Not now',
      // confirmText: 'Book',
    );
    if (picked != null && picked != _selectedDate.value) {
      setState(() {
        _selectedDate.value = picked;
      });
      currentDay = getCalendarReadingForDate(picked.subtract(const Duration(days: 13)).millisecondsSinceEpoch);
    }
  }

  void _showSelectDate(BuildContext context) {
      return buildMaterialDatePicker(context);
  }

  void _selectDate(DateTime? newSelectedDate) {
    if (newSelectedDate != null) {
      setState(() {
        _selectedDate.value = newSelectedDate;
      });
      currentDay = getCalendarReadingForDate(
          newSelectedDate.subtract(const Duration(days: 13)).millisecondsSinceEpoch
          // DateFormat('yyyy-MM-dd').format(
          //     newSelectedDate.subtract(const Duration(days: 13))
              // newSelectedDate
          // )
      );
    }
  }

  void onLoadUpdate(BuildContext context) async {
    Navigator.of(context).pop();
    final Uri url = Uri.parse('https://typikon.su/app/app.apk');
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
    var major = value.major;
    var minor = value.minor;
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Обновление'),
          content: Text('Появилось новое обновление: Версия $major.$minor'),
          actions: <Widget>[
            TextButton(
              onPressed: () => onSkipUpdate(context),
              child: const Text('Пропустить'),
            ),
            TextButton(
              onPressed: () => onLoadUpdate(context),
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

  @override
  Widget build(BuildContext context) {
    DateFormat format = DateFormat("dd.MM.yyyy");
    String value = _selectedDate.isRegistered ? format.format(_selectedDate.value) : "Не задано";
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(value, style: TextStyle(fontFamily: "OldStandard")),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.calendar_today,
              color: Colors.white,
            ),
            onPressed: () {
              _showSelectDate(context);
              // _restorableDatePickerRouteFuture.present();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
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
                  Text("В данных момент доступна библиотека книг и текстов, подборка чтений по дням Цветной Триоди, "
                      "календарные чтения на каждый день года, поиск по названию текста, "
                      "а также просмотр памятей на день. Ждите новых обновлений!", textAlign: TextAlign.justify,),
                ],
              ),
            ),
            // TextButton(
            //   onPressed: onGoToLibrary,
            //   child: Text("Посмотреть тексты в библиотеке"),
            // ),
            Padding(
              padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 12.0),
              child: Text(
                "Чтения Пролога на выбранную дату",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              child: FutureBuilder<DayResult>(
                  future: currentDay,
                  builder: (context, future) {
                    if (future.hasData) {
                      if (future.data == null) return SizedBox.shrink();
                      DayTexts? data = future.data?.data;
                      if (data == null) return SizedBox.shrink();
                      DayTextsParts? song6 = data?.song6;
                      if (song6 == null) return SizedBox.shrink();
                      List<DayTextsPart>? list = song6?.items;
                      if (list == null) return SizedBox.shrink();
                      return ListView.builder(
                              shrinkWrap: true,
                              scrollDirection: Axis.vertical,
                              itemCount: list.length,
                              physics: new NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                final item = list[index];
                                return Container(
                                  child: ListTile(
                                    title: Text(
                                        item.text?.name ?? "Без названия",
                                      style: TextStyle(fontFamily: "OldStandard", color: Colors.red),
                                    ),
                                    onTap: () => {
                                      Navigator.pushNamed(context, "/reading", arguments: item.text?.id)
                                    },
                                  ),
                                );
                              },
                        );
                    } else if (future.hasError) {
                      return Container(
                        child: Text('${future.error}'),
                      );
                    }
                    return Container(
                      color: const Color(0xffffffff),
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
                  },
                ),
            ),
            // TextButton(
            //   onPressed: onGoToCalculator,
            //   child: Text("Прочитать собранные чтения дня Триоди и Минеи (работает в пределах Цветной Триоди)"),
            // ),
            Text("Последние добавленные тексты", style: const TextStyle(fontWeight: FontWeight.bold)),
            Container(
              child: FutureBuilder<ReadingList>(
                future: lastTexts,
                builder: (context, future) {
                  if (future.hasData) {
                    List<Reading> list = future.data!.list;
                    return ListView.builder(
                          shrinkWrap: true,
                          scrollDirection: Axis.vertical,
                          physics: new NeverScrollableScrollPhysics(),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final item = list[index];
                            return Container(
                              child: ListTile(
                                title: Text(item.name ?? "test", style: TextStyle(fontFamily: "OldStandard", color: Colors.red),),
                                subtitle: Text(
                                    "Обновлено ${item.updatedAt.day}.${item.updatedAt.month}.${item.updatedAt.year}" ?? "test"),
                                onTap: () => {
                                  Navigator.pushNamed(context, "/reading", arguments: item.id)
                                },
                              ),
                            );
                          },
                    );
                  }
                  return Container(
                    color: const Color(0xffffffff),
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
                },
              ),
            ),
            Column(
              children: [
                Text("Цель и обоснование проекта", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Цель проекта заключается в собрании церковнославянского корпуса текстов уставных чтений и создании его последования, основываясь на Типиконе."),
                Text("Большая часть текстов отекстована в русском переводе и доступна для поиска. Тем не менее, даже в русскоязычном варианте не дается представления о том, что предлагает Типикон для чтения верующих в тот или иной день церковного года. В рамках данного проекта производится работа по отекстовке корпуса уставных чтений, соотнесение их с чтением в определенный день церковного года и сопоставление с корпусом русских текстов уставных чтений."),
                Text("Что такое уставные чтения?", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Уставные чтения — сборники нравоучительно-повествовательного характера, состоящие в основном из произведений дидактического и тор жественного красноречия, агиографических сочинений, а также полемических слов, толкований, кратких нравоучительных сентенций."),
                Text("О предмете уставных чтений", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("протопресвитер Василий Виноградов", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("В богатом содержанием современном Церковном Уставе скромно затерялось одно совершенно неприметное, по своей внешней бесцветности и нехарактерности, выражение, в отношении которого даже самый добросовестный рядовой читатель считает вполне для себя дозволительным не останавливать своего внимания, как на подробности слишком мелкой и слишком малозначительной."),
                Text("Это выражение состоит из одного слова, скромно вплетающегося в непрерывную цепь уставных указаний при помощи соединительного союза «и»: «и чтение». Но лаконически краткое и маловыразительное, оно неотступно преследует внимательного читателя «Устава» страница за страницей, встречает его глаз непременно в одних и тех же местах церковно-богослужебного последования: на утрене – после каждой кафизмы, на полиелее, после 3-ей и 6-ой песен канона, по отпуске пред первым часом, – и на всенощном бдении по окончании вечерни пред началом утрени."),
                Text("«Чтение... чтение... чтение»…"),
                Text("Что это за «чтение?» Большинство читателей Устава, читателей «ех officio», успокаивается на мысли, что здесь, разумеется, вообще какое-то, обычно непрактикуемое теперь, дополнительное чтение, в роде чтения псалтири или седальнов. Но при более внимательном ознакомлении с Уставом замечается, что лаконическое указание «чтение» по временам принимает более конкретный и определенный характер: «и чтение... чтется от слова иже во святых отца нашего... чтется от жития святого... от словес торжественных... слово Златоуста... слово Богослова... чтется от шестодневника Св. Василия Великого, чтется от толкований на Евангелие, на послание Павла апостола, оглашение преп. отца нашего Феодора Студита» и т. д. Отсюда для внимательного читателя «Устава» естественно следует приблизительно правильное общее представление о церковно-богослужебном факте, кроющемся под уставным термином «чтение»; это есть теперь уже обычно непрактикующееся чтение в определенные моменты богослужения церковно-учительных произведений, преимущественно житий святых и святоотеческих творений."),
                Text("Обычно думают, что Уставные Чтения это – одно из таких же мало выдающихся явлений исторической жизни Руси, как чтение псалтири или канонов за богослужением, как исследование об Уставных Чтениях понимается, как исследование одного узкоспециального археологически-литургического интереса с исследованиями о порядке чтения псалтири или канонов в русском богослужении давно минувшего времени. Иначе говоря, думают, что Уставные Чтения могут представлять интерес только со стороны своего литургического положения, как мелкий литургический факт, не допуская и мысли, чтобы это мог быть факт более высокой научной ценности и более широкого значения."),
                Text("А между тем Уставные Чтения – чрезвычайно важный факт в исторической жизни древней Руси."),
                Text("Об этом говорит уже простое сопоставление установленных наукой общих положений о характере идейной жизни древней Руси с указанным сейчас общим понятием об Уставных Чтениях как чтениях из церковно-учительных произведений, производившихся в древней Руси за богослужением."),
                Text("А. «В наше время, – писал проф. Иконников в 1869 г., – книга получила могущественное влияние и не редко заменяет школу, но в доброе старое время школа давала умственное направление обществу, и только отдельные умы, создавая новое, разрывали заветные связи со школою, из которой они вышли. Но в древней Руси школьное обучение имело узкий объем, ограничиваясь научением чтению по часослову и псалтири и письму, единственной же школой, где русское общество могло получать идейное поучение, была церковь – храм: а среди всех средств, которыми храм поучал общество, самым непосредственным и понятным средством, конечно, были Уставные Чтения. Отсюда вытекает вопрос о значении Уставных Чтений, как первостепенной силы, дававшей направление идейной жизни общества."),
                Text("Б. «В строгом смысле слова, до XVII века у нас не было науки. Наша литературная деятельность до того времени верно характеризуется названием книжности. Она стояла в самом тесном отношении к религии и была ее результатом; книжность должна была удовлетворять только религиозным потребностям». Но если древнерусская литературная деятельность стояла в самом тесном отношении к религии, как ее результат, то, конечно, она не могла не стоять в таком же отношении и к тем письменным произведениям, которые, выражая сущность этой религии, читались вслух всего церковного общества и при том в самом сердце религиозной жизни, в учреждении самого высшего религиозного авторитета, – в храме. А отсюда вытекает новый вопрос: об Уставных Чтениях как важнейшем источнике и вместе продукте древнерусской литературной деятельности."),
                Text("«Книжность в России распространялась главным образом чрез монастыри, и потому русская образованность древней эпохи может быть вполне названа монастырской». Но так как в монастырях вся жизнедеятельность имела сосредоточие в храме, в богослужении, то естественно, чтобы и образованность монастырская по своему характеру и идейному содержанию стояла в самой тесной зависимости от идейного содержания тех поучительных произведений, которые читались за богослужением в руководство всей братии, т. е. с Уставными Чтениями."),
              ],
            )
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Типикон ($majorVersion.$minorVersion.0)'),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, "/search");
                    },
                    child: Icon(
                      Icons.search,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Главная страница', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/",
              onTap: () {
                Navigator.pushNamed(context, "/");
              },
            ),
            ListTile(
              title: const Text('Избранное', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/favourites",
              onTap: () {
                Navigator.pushNamed(context, "/favourites");
              },
            ),
            ListTile(
              title: const Text('Библиотека', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/library",
              onTap: () {
                Navigator.pushNamed(context, "/library");
              },
            ),
            ListTile(
              title: const Text('Пятидесятница', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/penticostarion",
              onTap: () {
                Navigator.pushNamed(context, "/penticostarion");
              },
            ),
            ListTile(
              title: const Text('Триодион', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/triodion",
              onTap: () {
                Navigator.pushNamed(context, "/triodion");
              },
            ),
            ListTile(
              title: const Text('Чтения на календарный день', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/months",
              onTap: () {
                Navigator.pushNamed(context, "/months");
              },
            ),
            ListTile(
              title: const Text('Калькулятор чтений на день', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/calculator",
              onTap: () {
                Navigator.pushNamed(context, "/calculator");
              },
            ),
            ListTile(
              title: const Text('Памяти на день', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/dneslov/memories",
              onTap: () {
                Navigator.pushNamed(context, "/dneslov/memories");
              },
            ),
            ListTile(
              title: const Text('Обратная связь', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/contact",
              onTap: () {
                Navigator.pushNamed(context, "/contact");
              },
            ),
            ListTile(
              title: const Text('Настройки', style: TextStyle(fontSize: 14.0),),
              selected: ModalRoute.of(context)?.settings.name == "/settings",
              onTap: () {
                Navigator.pushNamed(context, "/settings");
              },
            ),
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
              onTap: () => onLoadUpdate(context),
            ),
          ],
        ),
      ),
    );
  }
}