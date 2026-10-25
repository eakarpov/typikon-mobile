import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:file_saver_ffi/file_saver_ffi.dart';
import 'package:flutter/material.dart';

import 'package:typikon/components/reading_markdown.dart';
import 'package:typikon/main.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_redux/flutter_redux.dart';

import "package:typikon/components/api_error_view.dart";
import "package:typikon/utils/fb2.dart";
import "package:typikon/api/constants.dart";
import "package:typikon/components/fusion_text.dart";
import "package:typikon/components/selection_menu.dart";
import "package:typikon/components/report_error_sheet.dart";
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/favourites_sync.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/reading_progress.dart';
import 'package:typikon/utils/pericope_route.dart';
import 'package:typikon/dto/place.dart';
import 'package:typikon/dto/text.dart';
import 'package:typikon/dto/user_note.dart';
import 'package:typikon/dto/dneslov/images.dart';
import '../apiMapper/places.dart';
import '../apiMapper/reading.dart';
import '../apiMapper/user_notes.dart';
import "../apiMapper/dneslov/images.dart";
import 'package:typikon/components/text_search_sheet.dart';
import 'package:typikon/components/table_of_contents.dart';
import 'package:typikon/utils/reading_style.dart';
import 'package:typikon/utils/text_headings.dart';
import 'package:typikon/utils/text_search.dart';
import 'package:typikon/store/store.dart';
import "package:typikon/components/script_toggle.dart";
import "package:typikon/utils/script_convert.dart";
import "package:typikon/components/pinch_zoom.dart";

class TextPage extends StatefulWidget {
  final String id;

  const TextPage(context, {super.key, required this.id});

  @override
  State<TextPage> createState() => _TextPageState();
}

class _TextPageState extends State<TextPage> with WidgetsBindingObserver {
  late Future<Reading> reading;

  /// Размеченный вид, если его просили. `null` — не просили либо не вышло.
  AccentedText? _accented;

  /// Идёт ли запрос: пока идёт, переключатель заперт — два нажатия подряд завели
  /// бы два запроса и показали бы ответ того, который вернулся вторым.
  bool _accentsLoading = false;

  /// Показывать ли ударения СЕЙЧАС, на этом экране.
  ///
  /// Начальное значение берётся из настроек, дальше живёт здесь: `StoreProvider`
  /// сравнивает магазины, а не состояния, и сам по себе перерисовки не даёт —
  /// та же причина, по которой подборщик изданий Библии зовёт `setState`.
  bool _showAccents = false;

  Future<void> _toggleAccents(Reading data) async {
    final wanted = !_showAccents;
    appStore?.dispatch(ChangeShowAccentsAction(wanted));

    if (!wanted) {
      setState(() => _showAccents = false);
      return;
    }
    if (_accented != null) {
      setState(() => _showAccents = true);
      return;
    }

    setState(() => _accentsLoading = true);
    try {
      final view = await getTextAccents(_realId);
      if (!mounted) return;
      setState(() {
        _accented = view;
        _showAccents = true;
        _accentsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      // Возвращаем переключатель в книжный вид и говорим, что не вышло: молча
      // показать книгу значило бы, что человек нажал и ничего не заметил.
      setState(() {
        _showAccents = false;
        _accentsLoading = false;
      });
      appStore?.dispatch(ChangeShowAccentsAction(false));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(error, "Не удалось расставить ударения"))),
      );
    }
  }
  /// Места, названные в этом тексте: разметкой и разбором, принятым на сверке.
  ///
  /// Молча пусто при отказе — это прибавка к чтению, а не само чтение, и ради
  /// неё показывать ошибку поверх текста незачем.
  List<TextPlaceRef> _places = const [];

  late Future<DneslovImageListD> dneslovImages;

  // "Читать целиком" со страницы зачала кодирует его границы суффиксом в id
  // маршрута — см. utils/pericope_route.dart. Так не пришлось менять сигнатуру
  // всех существующих pushNamed(context, "/reading", ...).
  late final String _realId;

  /// Якорь на начало зачала — к нему прокручиваем и по нему же ведёт
  /// оглавление. Ставится на первый подсвеченный блок.

  List<UserNote> _userNotes = [];


  final ScrollController _scrollController = ScrollController();
  Timer? _persistDebounce;
  bool _resumeBannerShown = false;

  /// Поиск по тексту: совпадения для подсветки (индекс абзаца → диапазоны) и
  /// номер текущего совпадения в плоском списке. Считаются по тому виду
  /// текста, что на экране: искать «и́стину» и красить по книжному «истину»
  /// значило бы не найти своего же совпадения.
  Map<int, List<TextRange>> _searchMatches = const {};
  int _searchCurrent = 0;

  /// Якоря абзацев для прокрутки к совпадению поиска и к главе оглавления:
  /// создаются лениво, по индексу абзаца (см. days_page.dart).
  final Map<int, GlobalKey> _paragraphKeys = {};

  // MaterialBanner живёт в ScaffoldMessenger, а тот — выше MaterialApp, то есть
  // переживает уход со страницы: не нажав ни "Сначала", ни "Продолжить",
  // пользователь уносил баннер с собой на следующий экран. Снимаем его в
  // dispose, а ссылку на messenger берём заранее — в dispose искать его по
  // дереву уже поздно.
  ScaffoldMessengerState? _messenger;
  bool _bannerVisible = false;


  @override
  void initState() {
    super.initState();
    _showAccents = appStore?.state.settings.showAccents ?? false;
    _realId = readingTextId(widget.id);
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadReading();
    _loadUserNotes();
    _loadPlaces();

  }

  Future<void> _loadPlaces() async {
    try {
      final found = await getTextPlaces(_realId);
      if (mounted) setState(() => _places = found);
    } catch (_) {
      // Молчим нарочно: см. _places.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    if (_bannerVisible) _messenger?.hideCurrentMaterialBanner();
    _persistDebounce?.cancel();
    _persistProgressNow();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _persistProgressNow();
    }
  }

  /// Доля прокрутки на последнем движении.
  ///
  /// Запоминается, потому что в `dispose` спросить её уже не у кого: дети
  /// снимаются с дерева раньше родителя, и контроллер к тому времени без
  /// клиентов. Прокрутил, сразу нажал «назад» — и место терялось: пауза в две
  /// секунды отменена, а запись на выходе молча выходила по `hasClients`.
  double? _lastFraction;

  /// Имя открытого текста: для списка «продолжить чтение» на главной. Живёт
  /// ответом сервера, а не аргументом маршрута — идентификатор зачала несёт
  /// суффикс границ (см. utils/pericope_route.dart), и подписать им записью
  /// прогресс нельзя.
  String? _readingName;

  void _onScroll() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      if (position.maxScrollExtent > 0) {
        _lastFraction = (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
      }
    }
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 2), _persistProgressNow);
  }

  void _persistProgressNow() {
    final fraction = _lastFraction;
    // Не прокручивали — записывать нечего, и прежнюю запись не затираем.
    if (fraction == null) return;
    saveReadingProgress(_realId, fraction, name: _readingName);
  }

  Future<void> _checkResumeProgress() async {
    final progress = await getReadingProgress(_realId);
    if (progress == null || _resumeBannerShown || !mounted) return;
    _resumeBannerShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showResumeBanner(progress.fraction);
    });
  }

  void _hideResumeBanner() {
    if (!_bannerVisible) return;
    _bannerVisible = false;
    _messenger?.hideCurrentMaterialBanner();
  }

  void _showResumeBanner(double fraction) {
    _bannerVisible = true;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text("Вы уже читали этот текст. Продолжить с места, где остановились?"),
        actions: [
          TextButton(
            onPressed: () {
              _hideResumeBanner();
              clearReadingProgress(_realId);
            },
            child: Text("Сначала"),
          ),
          TextButton(
            onPressed: () {
              _hideResumeBanner();
              _resumeTo(fraction);
            },
            child: Text("Продолжить"),
          ),
        ],
      ),
    );
  }

  void _resumeTo(double fraction) {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo((fraction * maxExtent).clamp(0.0, maxExtent));
  }

  /// Письмо — тем же приёмом, поверх ударений: подменяется та же
  /// переменная, и выгрузка в fb2 по-прежнему уносит книгу.
  String _presentedContent(Reading data) {
    final content = _showAccents && _accented != null
        ? _accented!.content
        : data.content;
    return presentScript(content, _scriptOf(data), readerScript(context));
  }

  /// Совпадение, на котором стоит листание: (индекс абзаца, диапазон).
  (int, TextRange)? _currentSearchMatch() {
    var index = 0;
    for (final entry in _searchMatches.entries) {
      for (final range in entry.value) {
        if (index == _searchCurrent) return (entry.key, range);
        index++;
      }
    }
    return null;
  }

  void _scrollToCurrentSearchMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _currentSearchMatch();
      if (current == null) return;
      final key = _paragraphKeys.putIfAbsent(current.$1, () => GlobalKey());
      final targetContext = key.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    });
  }

  /// Шторка поиска держит запрос и совпадения, страница — только подсветку:
  /// каждое изменение приходит сюда вместе с номером текущего совпадения.
  Future<void> _openTextSearch(List<String> paragraphs) async {
    await showTextSearchSheet(
      context,
      paragraphs: paragraphs,
      onChanged: (matches, current) {
        if (!mounted) return;
        setState(() {
          _searchMatches = matches;
          _searchCurrent = current;
        });
        _scrollToCurrentSearchMatch();
      },
    );
    // Шторка закрыта (крестик, свайп, шаг назад) — подсветка снимается.
    if (!mounted) return;
    setState(() {
      _searchMatches = const {};
      _searchCurrent = 0;
    });
  }

  /// Глава внутри длинного текста: оглавление из найденных заголовков.
  void _openTableOfContents(List<String> paragraphs) {
    final headings = findTextHeadings(paragraphs);
    if (headings.length < 2) return;
    showTableOfContents(
      context,
      headings
          .map((heading) => TocEntry(
                title: heading.title,
                anchorKey: _paragraphKeys.putIfAbsent(heading.paragraphIndex, () => GlobalKey()),
              ))
          .toList(),
    );
  }

  void _loadReading() {
    _resumeBannerShown = false;
    reading = getText(_realId);
    reading.then((value) {
      _readingName = value.name;
      if (value.dneslovId != null) {
        dneslovImages = fetchDneslovImagesD(value.dneslovId!);
      }
      _checkResumeProgress();
    });
  }

  void _retry() {
    setState(_loadReading);
  }

  void _loadUserNotes() {
    // listen: false — метод зовётся из initState, а подписка на наследника
    // до конца initState запрещена: читаем стор одним разом, без зависимости.
    if (!StoreProvider.of<AppState>(context, listen: false).state.auth.isSignedIn) return;
    getUserNotes(textId: _realId).then((notes) {
      if (!mounted) return;
      setState(() { _userNotes = notes; });
    }).catchError((error) {
      // Заметки — дополнение к тексту, а не он сам: если сессия истекла или
      // сервер недоступен, страница просто показывает текст без подсветок.
      // withSession уже погасил локальный вход, поэтому пункты меню выделения
      // пропадут при следующей перерисовке.
      if (!mounted) return;
      setState(() { _userNotes = []; });
    });
  }

  /// Письмо текста. Уставом — только отмеченные `csSource`; прочие тексты
  /// библиотеки языка не называют, и среди них есть русские: их не переводим.
  TextScript _scriptOf(Reading reading) =>
      reading.csSource ? TextScript.church : TextScript.other;

  /// Заметки для подсветки переведённого текста.
  ///
  /// Заметка хранит книжное написание, а в тексте теперь другое, и подсветка
  /// её не нашла бы — ни ошибки, ни следа. Фраза переводится тем же правилом,
  /// что и текст; по нажатию открывается сама заметка, а не эта копия.
  List<UserNote> _presentedNotes(TextScript script, String setting) => _userNotes
      .map((note) => UserNote(
            id: note.id,
            textId: note.textId,
            note: note.note,
            textName: note.textName,
            selection: NoteSelection(
              type: note.selection.type,
              phrase: presentScript(note.selection.phrase, script, setting),
              paragraphIndex: note.selection.paragraphIndex,
              paragraph: note.selection.paragraph,
              chapter: note.selection.chapter,
              verse: note.selection.verse,
              verseText: note.selection.verseText,
            ),
          ))
      .toList();

  void _onTapUserNote(UserNote note) {
    showAddNoteSheet(
      context,
      textId: _realId,
      contextText: note.selection.type == 'verse'
          ? (note.selection.verseText ?? '')
          : (note.selection.paragraph ?? ''),
      phrase: note.selection.phrase,
      paragraphIndex: note.selection.paragraphIndex,
      chapter: note.selection.chapter,
      verse: note.selection.verse,
      existingNote: note,
      onChanged: _loadUserNotes,
    );
  }

  Widget _buildError(BuildContext context, Object? error) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      width: double.infinity,
      height: double.infinity,
      child: ApiErrorView(
        error: error,
        message: "Не удалось загрузить текст.",
        offlineMessage:
            "Нет соединения с интернетом. Этот текст ещё не открывали, поэтому офлайн он недоступен.",
        onRetry: _retry,
      ),
    );
  }

  /// Выгрузка текста в fb2. Сборка xml вынесена в utils/fb2.dart — там же
  /// экранирование и разбивка на абзацы, и там же её проверяет тест.
  Future<void> _exportFb2(Reading reading) async {
    final fb2Content = buildFb2(
      id: reading.id,
      name: reading.name,
      author: reading.author,
      content: reading.content,
      now: DateTime.now(),
    );

    final Uri uri = await FileSaver.instance.saveBytesAsync(
      fileName: fb2FileName(reading.name),
      bytes: utf8.encode(fb2Content),
      fileType: CustomFileType(ext: 'fb2', mimeType: 'application/x-fictionbook'),
      conflictResolution: ConflictResolution.autoRename,
    );

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'downloadChannelId',
      'downloadNotificationChannel',
      channelDescription: 'Notifications about saved files',
      importance: Importance.max,
      priority: Priority.high,
      ticker: "download ticker",
    );
    final iOSPlatformChannelSpecifics = DarwinNotificationDetails();
    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id++,
      'Уставные чтения',
      'Файл сохранён. Нажмите, чтобы открыть.',
      platformChannelSpecifics,
      payload: "download - ${uri.toString()}",
    );
  }

  void onClick(String link) {
    Uri myUrl = Uri.parse(link);
    launchUrl(myUrl);
  }

  /// Ссылка на это чтение для «Поделиться»: куда указывает адрес сайта.
  /// Состав текста отправки (фраза плюс ссылка) собирает само меню выделения.
  String _shareLinkFor(String phrase) => "https://$siteHostFull/reading/$_realId";

  Widget imageCard(value) {
    return Image(
      image: NetworkImage(value),
    );
  }

  /// Отметка ставится в сторе — оттуда её видят и сердечко, и страница
  /// избранного, — а на сервер уезжает сама, когда есть сеть.
  void onLike() {
    final store = StoreProvider.of<AppState>(context);
    store.dispatch(ToggleFavouriteAction(_realId));
    unawaited(syncFavourites(store));
  }



  /// Само зачало внутри книги: подложка, полоса слева и подписи с обоих концов.
  ///
  /// Раньше "читать целиком" только прокручивало к нужной главе, и где чтение
  /// начинается, а главное — где кончается, приходилось угадывать.

  /// Режет главу на куски по границам зачала. Внутри границ — выделенный блок,
  /// остальное рисуется как обычно.
  ///
  /// [runsBefore] — сколько кусков зачала уже нарисовано в предыдущих главах, а
  /// [totalRuns] — сколько их всего: только зная и то, и другое, можно
  /// подписать первый кусок началом, а последний — концом. Зачало бывает и
  /// разорванным (две-три группы стихов), и переходящим через границу главы.


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Reading>(
          future: reading,
          builder: (context, future) {
            if (future.hasData) {
              String name = future.data!.name;
              return Text(name, style: TextStyle(fontFamily: "OldStandard"));
            } else if (future.hasError) {
              return Text(
                "Ошибка загрузки",
                style: TextStyle(fontFamily: "OldStandard"),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }
            return const CircularProgressIndicator();
          },
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40.0), // here the desired height
          child: FutureBuilder(future: reading, builder: (context, future) {
            if (future.hasData) {
              return Row(
                children: <Widget>[
                  if (future.data!.ruLink != null) TextButton(
                    onPressed: () => onClick(future.data!.ruLink as String),
                    child: Text("РУ", style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white),),
                  ),
                  if (future.data!.link != null) TextButton(
                    onPressed: () => onClick(future.data!.link as String),
                    child: Text("ЦС", style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white),),
                  ),
                  if (future.data!.dneslovId != null) IconButton(
                      tooltip: "К святому",
                      onPressed: () => Navigator.pushNamed(context, "/saints", arguments: future.data!.dneslovId),
                      icon: Icon(Icons.person, color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white),
                  ),
                  if (future.data!.bookId != null) IconButton(
                      tooltip: "К книге",
                      onPressed: () => Navigator.pushNamed(context, "/library", arguments: future.data!.bookId),
                      icon: Icon(Icons.menu_book, color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white),
                  ),
                  if (future.data!.dayId != null) IconButton(
                      tooltip: "К дню",
                      onPressed: () => Navigator.pushNamed(context, "/days", arguments: future.data!.dayId),
                      icon: Icon(Icons.calendar_month, color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white),
                  ),
                ],
              );
            }
            return Row(children: []);
          }),
        ),
        actions: <Widget>[
          // Сердечко берёт состояние из стора, а не из своего поля: раньше оно и
          // страница избранного читали SharedPreferences по отдельности и
          // расходились, пока экран не перезапросишь.
          StoreConnector<AppState, bool>(
            distinct: true,
            converter: (store) => store.state.favourites.contains(_realId),
            builder: (context, isFavourite) => IconButton(
              onPressed: onLike,
              tooltip: isFavourite ? "Убрать из избранного" : "В избранное",
              icon: isFavourite
                  ? const Icon(Icons.favorite, color: Colors.pink)
                  : const Icon(Icons.favorite_outline),
            ),
          ),
          // Ударения предлагаются только там, где корпус размечен не полностью:
          // у прочих текстов знаки уже стоят в самой книге, и переключатель,
          // ничего не меняющий, только сбивал бы.
          FutureBuilder<Reading>(
            future: reading,
            builder: (context, future) {
              if (!future.hasData || future.data!.accents == null) {
                return const SizedBox.shrink();
              }
              if (_accentsLoading) {
                return Padding(
                  padding: EdgeInsets.all(14.0),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white),
                  ),
                );
              }

              return IconButton(
                icon: Icon(_showAccents ? Icons.text_fields : Icons.text_fields_outlined),
                tooltip: _showAccents ? "Как в книге" : "Расставить ударения",
                onPressed: () => _toggleAccents(future.data!),
              );
            },
          ),
          FutureBuilder<Reading>(
            future: reading,
            builder: (context, future) => ScriptToggle(
              source: future.hasData ? _scriptOf(future.data!) : TextScript.other,
              onChanged: () => setState(() {}),
            ),
          ),
          FutureBuilder<Reading>(
            future: reading,
            builder: (context, future) {
              if (!future.hasData || future.data!.newUi) {
                return const SizedBox.shrink();
              }
              final paragraphs = _presentedContent(future.data!).split("\n\n");
              return IconButton(
                tooltip: "Искать в тексте",
                icon: const Icon(Icons.search),
                onPressed: () => _openTextSearch(paragraphs),
              );
            },
          ),
          FutureBuilder<Reading>(
            future: reading,
            builder: (context, future) {
              if (!future.hasData || future.data!.newUi) {
                return const SizedBox.shrink();
              }
              // Оглавление имеет смысл, только когда глав в тексте больше одной:
              // у двухсот заголовков список на весь экран, а выбирать не из чего.
              final paragraphs = _presentedContent(future.data!).split("\n\n");
              if (findTextHeadings(paragraphs).length < 2) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: "Оглавление",
                icon: const Icon(Icons.toc),
                onPressed: () => _openTableOfContents(paragraphs),
              );
            },
          ),
          FutureBuilder<Reading>(
            future: reading,
            builder: (context, future) {
              if (future.hasData) {
                return IconButton(
                  icon: Icon(Icons.file_download, color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white),
                  tooltip: "Сохранить в fb2",
                  onPressed: () => _exportFb2(future.data!),
                );
              } else if (future.hasError) {
                return SizedBox.shrink();
              }
              return const CircularProgressIndicator();
            },
          ),
        ],
      ),
      body: PinchZoom(child: Container(
        color: readingBackgroundColor(context),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        // Ширину колонки читатель выбирает сам; без выбора обёртка не делает
        // ничего.
        child: ReadingColumn(child: FutureBuilder<Reading>(
          future: reading,
          builder: (context, future) {
            if (future.hasData) {
              // Показываем размеченный вид, если он спрошен и получен. Подменяем
              // ИМЕННО эту переменную: из неё питаются и `containers:` для
              // выделения, и рисуемые абзацы, — одной подменой оба остаются
              // согласованными. Сам `Reading` не трогается, и потому выгрузка в
              // fb2 (`_exportFb2`) уносит книгу, а не машинные знаки.
              String content = _presentedContent(future.data!);
              final script = _scriptOf(future.data!);
              final setting = readerScript(context);
              final converted = convertsScript(script, setting);
              final paragraphs = content.split("\n\n");
              // Текущее совпадение поиска подсвечивается контрастнее; прочие —
              // обычным фоном. Заголовки глав — для оглавления внутри текста.
              final currentSearch = _currentSearchMatch();
              final headings = future.data!.newUi
                  ? const <TextHeading>[]
                  : findTextHeadings(paragraphs);
              final notes = converted ? _presentedNotes(script, setting) : _userNotes;
              String name = future.data!.name;
              return SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 12.0),
                        child: Text(
                            name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                            )
                        ),
                      ),
                      future.data!.newUi ? (
                          // Не Markdown в SizedBox(height: 350): страница
                          // прокручивается сама, а окошко со своей прокруткой
                          // посреди неё резало текст и не знало ни одной
                          // настройки чтения.
                          // Меню — без заметок: они привязаны к номеру абзаца
                          // по двойному переводу строки, а markdown делит текст
                          // на абзацы по-своему, и номер разошёлся бы с экраном.
                          SelectionMenu.wordsOnly(
                            shareLinkFor: _shareLinkFor,
                            child: ReadingMarkdown(content, scrollable: false),
                          )
                        ) : (
                            SelectionMenu(
                              // В переведённом виде заметку и сообщение об
                              // ошибке не заводим: они ушли бы на сервер не
                              // книжным написанием, а нашим переводом.
                              enabled: StoreProvider.of<AppState>(context).state.auth.isSignedIn &&
                                  !converted,
                              textId: _realId,
                              shareLinkFor: _shareLinkFor,
                              containers: paragraphs.asMap().entries.map((entry) =>
                                  TextContainer.paragraph(paragraphIndex: entry.key, text: entry.value)
                              ).toList(),
                              child: Column(
                                children: paragraphs.asMap().entries.map((entry) {
                                  // Якорь нужен абзацу с заголовком главы
                                  // (оглавление) и с совпадением поиска
                                  // (прокрутка к нему); прочие оборачивать
                                  // незачем.
                                  final needsKey = headings.any((h) => h.paragraphIndex == entry.key) ||
                                      _searchMatches.containsKey(entry.key);
                                  final widget = FusionTextWidgets(
                                    text: entry.value,
                                    footnotes: future.data?.footnotes??[],
                                    fontFamily: presentFont(
                                        future.data!.csSource ? "Monomakh" : "OldStandard",
                                        script,
                                        setting),
                                    notes: notes.where((n) =>
                                        n.selection.type == 'paragraph' && n.selection.paragraphIndex == entry.key
                                    ).toList(),
                                    onTapNote: (note) => _onTapUserNote(
                                        _userNotes.firstWhere((n) => n.id == note.id,
                                            orElse: () => note)),
                                    searchMatches: _searchMatches[entry.key] ?? const [],
                                    activeMatch: currentSearch != null &&
                                            currentSearch.$1 == entry.key
                                        ? currentSearch.$2
                                        : null,
                                  );
                                  if (!needsKey) return widget;
                                  return Container(
                                    key: _paragraphKeys.putIfAbsent(entry.key, () => GlobalKey()),
                                    child: widget,
                                  );
                                }).toList(),
                              ),
                            )
                        ),
                      ScriptCaveat(source: script),
                      // Оговорка теми же словами, что на сайте. Она обязательна:
                      // без неё машинная догадка выдаётся за книгу, а решение
                      // писать эти знаки в самый корпус остаётся за хозяином.
                      if (_showAccents && _accented != null) Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          "Ударения расставлены машинно по словарю собрания: "
                          "${_accented!.marked} из ${_accented!.expected} слов, которым "
                          "знак положен. Спорные места оставлены без знака. В самом "
                          "тексте ударений нет — это подсказка для чтения вслух, а не книга.",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (_places.isNotEmpty) Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // Статья энциклопедии — о самом месте; прочие
                              // тексты место лишь называют, и смешивать это
                              // значило бы обещать статью там, где упоминание.
                              _places.any((place) => place.subject)
                                  ? "Место:"
                                  : "Места:",
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 6.0),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 4.0,
                              children: _places
                                  .map((place) => ActionChip(
                                        label: Text(place.name),
                                        avatar: place.subject
                                            ? const Icon(Icons.article_outlined, size: 16.0)
                                            : const Icon(Icons.place_outlined, size: 16.0),
                                        onPressed: () => Navigator.pushNamed(
                                          context, "/places", arguments: place.address),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      if (future.data!.dneslovId != null) FutureBuilder<DneslovImageListD>(
                          future: dneslovImages,
                          builder: (context, future) {
                            if (future.hasData) {
                              return CarouselSlider(
                                options: CarouselOptions(height: 400.0),
                                items: future.data!.list.map((item) {
                                  return Builder(
                                    builder: (BuildContext context) {
                                      return Container(
                                          width: MediaQuery.of(context).size.width,
                                          margin: EdgeInsets.symmetric(horizontal: 5.0),
                                          decoration: BoxDecoration(
                                          ),
                                          child: Image(
                                            image: NetworkImage(item.thumb_url),
                                          ),
                                      );
                                    },
                                  );
                                }).toList(),
                              );
                              // return Column(
                              //   children: future.data!.list.map((item) => imageCard(item.url)).toList(),
                              // );
                            }
                            return Image.asset("assets/images/trinity.jpeg");
                          }
                      ),
                      if (future.data!.dneslovId == null) Image.asset("assets/images/trinity.jpeg"),
                    ],
                  ),
                ),
              );
            } else if (future.hasError) {
              return _buildError(context, future.error);
            }
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: double.infinity,
              height: double.infinity,
              child: Align(
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
            );
          },
        ))),
      ),
    );
  }
}
