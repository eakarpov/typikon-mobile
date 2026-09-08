import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../apiMapper/bible.dart';
import '../apiMapper/v2/errors.dart';
import '../components/api_error_view.dart';
import '../components/bible_edition_picker.dart';
import '../components/bible_parallel_view.dart';
import '../components/chapter_grid.dart';
import '../components/pericope_block.dart';
import '../components/verse_list.dart';
import '../dto/bible.dart';
import '../dto/pericope.dart';
import '../store/actions/actions.dart';
import '../store/bible_bookmark.dart';
import '../store/models/models.dart';
import '../utils/bible_editions.dart';
import '../utils/bible_route.dart';
import '../utils/bible_style.dart';

/// Глава Библии.
///
/// Вид переключается не тумблером, а самим выбором изданий: одно — сплошной
/// текст через готовый `VerseListView`, это девяносто пять процентов случаев и
/// это чтение книги; два и больше — построчное чередование, потому что в
/// параллельном виде не читают, а сличают.
class BibleChapterPage extends StatefulWidget {
  const BibleChapterPage(
    context, {
    super.key,
    required this.canonId,
    required this.chapter,
    this.highlight = const [],
  });

  final String canonId;
  final int chapter;

  /// Границы зачала, если пришли со страницы дня. Пусто — обычное чтение главы.
  final List<PericopeRange> highlight;

  @override
  State<BibleChapterPage> createState() => _BibleChapterPageState();
}

class _BibleChapterPageState extends State<BibleChapterPage> {
  late Future<BibleChapter> chapter;

  /// Число глав в книге — из оглавления. Нужно для сетки глав и для того, чтобы
  /// не предлагать «следующую» за последней. Не загрузилось — обходимся: сетку
  /// не показываем, переход вперёд оставляем, а честный `404` от сервера скажет
  /// то же самое словами.
  int? chaptersInBook;

  /// Список изданий — для листа выбора. Держим отдельно от главы: глава знает
  /// только те издания, что у неё запрошены, а выбирать надо из всех.
  BibleEditionList available = const BibleEditionList([]);

  /// Якорь на начало зачала: к нему прокручиваем после первого кадра, иначе
  /// читатель, пришедший за чтением дня, оказался бы в начале главы и искал
  /// зачало глазами — ровно то, от чего эта работа и затевалась.
  final GlobalKey _pericopeKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  bool _scrolledToPericope = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadChapterCount();
  }

  void _load() {
    _scrolledToPericope = false;
    chapter = _loadChapter();
    if (widget.highlight.isNotEmpty) {
      chapter.then((_) => _scrollToPericope()).catchError((_) => null);
    }
  }

  void _scrollToPericope() {
    if (_scrolledToPericope || !mounted) return;
    _scrolledToPericope = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _pericopeKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    });
  }

  @override
  void dispose() {
    _rememberPlace();
    _scrollController.dispose();
    super.dispose();
  }

  /// Закладка ставится при уходе со страницы — но только с той, которую открыли
  /// ради чтения.
  ///
  /// Приход из зачала закладку не двигает: это не чтение подряд, а справка по
  /// службе. Иначе у того, кто каждое утро открывает Евангелие дня, закладка
  /// вечно стояла бы на дневном чтении и никогда — на том, что он читает сам.
  /// А вот шаг дальше («Глава 7 →») закладку уже ставит: у той страницы
  /// подсветки нет, и открыта она намеренно.
  void _rememberPlace() {
    if (widget.highlight.isNotEmpty) return;
    saveBibleBookmark(widget.canonId, widget.chapter);
  }

  Future<BibleChapter> _loadChapter() async {
    // Список изданий нужен и чтобы узнать эталон (а не гадать про `cs-eliz`), и
    // чтобы было из чего выбирать. Не пришёл — идём без параметра: сервер поймёт
    // это как «все публичные», и это лучше пустого экрана.
    try {
      final editions = await getBibleEditions();
      if (mounted) setState(() => available = editions);
    } catch (_) {}

    return getBibleChapter(
      widget.canonId,
      widget.chapter,
      editions: resolveEditionCodes(_chosenEditions, available),
    );
  }

  List<String> get _chosenEditions =>
      StoreProvider.of<AppState>(context, listen: false).state.settings.bibleEditions;

  Future<void> _pickEditions() async {
    if (available.list.isEmpty) return;

    final store = StoreProvider.of<AppState>(context, listen: false);
    final picked = await showEditionPicker(
      context,
      editions: available.list,
      selected: resolveEditionCodes(_chosenEditions, available),
    );
    if (picked == null || picked.isEmpty) return;

    store.dispatch(ChangeBibleEditionsAction(picked));
    if (mounted) setState(_load);
  }

  Future<void> _loadChapterCount() async {
    try {
      final books = await getBibleBooks();
      if (!mounted) return;
      setState(() => chaptersInBook = books.byId(widget.canonId)?.chapters);
    } catch (_) {
      // Оглавление не обязательно: без него страница беднее, но работает.
    }
  }

  void _openChapter(int number) {
    Navigator.pushReplacementNamed(
      context,
      "/bible",
      arguments: bibleRouteArgument(widget.canonId, chapter: number),
    );
  }

  Future<void> _pickChapter(String bookName) async {
    final total = chaptersInBook;
    if (total == null) return;

    final picked = await showChapterPicker(
      context,
      bookName: bookName,
      chapters: total,
      current: widget.chapter,
    );
    if (picked != null && picked != widget.chapter) _openChapter(picked);
  }

  @override
  Widget build(BuildContext context) {
    final settings = StoreProvider.of<AppState>(context).state.settings;

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<BibleChapter>(
          future: chapter,
          builder: (context, future) => Text(
            future.hasData
                // Имя книги — из ответа сервера, а не из оглавления: тогда
                // незнакомый идентификатор не роняет экран и не показывает
                // «Без названия».
                ? "${future.data!.book.name}, глава ${future.data!.chapter}"
                : "Библия",
            style: const TextStyle(fontFamily: "OldStandard", fontSize: 18.0),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            tooltip: "Издания",
            onPressed: available.list.isEmpty ? null : _pickEditions,
          ),
          FutureBuilder<BibleChapter>(
            future: chapter,
            builder: (context, future) {
              if (!future.hasData || chaptersInBook == null) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.grid_view),
                tooltip: "Главы",
                onPressed: () => _pickChapter(future.data!.book.name),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: settings.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        child: FutureBuilder<BibleChapter>(
          future: chapter,
          builder: (context, future) {
            if (future.hasError) return _error(future.error);
            if (!future.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _chapter(context, future.data!, settings.fontSize.toDouble());
          },
        ),
      ),
    );
  }

  Widget _error(Object? error) {
    // «Слишком часто» — не поломка и не вина читателя, и общее «не удалось
    // загрузить» здесь было бы враньём.
    if (error is ApiRateLimitedException) {
      return ApiErrorView(
        error: error,
        message: error.message,
        hint: error.hint,
        onRetry: () => setState(_load),
      );
    }

    // Сообщение сервера точнее нашего: «В этих изданиях такой главы нет» — не
    // ошибка приложения, а честный ответ про Исход 37–39 или про Апокалипсис,
    // которого нет в китайском Новом Завете.
    if (error is ApiNotFoundException) {
      return ApiErrorView(error: error, message: error.message);
    }

    return ApiErrorView(
      error: error,
      message: "Не удалось загрузить главу.",
      offlineMessage: "Эта глава ещё не читалась, а сети сейчас нет.",
      onRetry: () => setState(_load),
    );
  }

  Widget _chapter(BuildContext context, BibleChapter data, double fontSize) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.editions.length > 1)
            BibleParallelView(
              chapter: data,
              fontSize: fontSize,
              highlight: widget.highlight,
              rangesLabel: _rangesLabel,
              firstKey: _pericopeKey,
            )
          else
            _single(context, data, fontSize),
          ..._numberingNotes(context, data),
          _navigation(context),
        ],
      ),
    );
  }

  Widget _single(BuildContext context, BibleChapter data, double fontSize) {
    final edition = data.editions.isEmpty ? null : data.editions.first;
    final verses = data.versesFor(0);
    final fontFamily = bibleFontFamily(edition?.language ?? "");

    if (verses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Text("В этом издании главы нет."),
      );
    }

    if (widget.highlight.isEmpty) {
      return VerseListView(verses: verses, fontSize: fontSize, fontFamily: fontFamily);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: buildPericopeBlocks(
        context,
        verses: verses,
        ranges: widget.highlight,
        fontSize: fontSize,
        fontFamily: fontFamily,
        rangesLabel: _rangesLabel,
        firstKey: _pericopeKey,
      ),
    );
  }

  String get _rangesLabel => widget.highlight.map((range) => range.label).join("; ");

  /// Оговорка про счёт.
  ///
  /// Показывается только там, где она нужна: у эталона обе нумерации совпадают,
  /// а вот греческие Притчи открываются в славянском счёте, и читатель не найдёт
  /// своей 24-й главы там, где привык. Замолчать это нельзя — режим счёта самого
  /// издания в первой итерации не сделан, и цену отказа надо назвать.
  List<Widget> _numberingNotes(BuildContext context, BibleChapter data) {
    final others = data.editions.where((edition) => !edition.isReference).toList();
    if (others.isEmpty) return const [];

    final names = others.map((edition) => "«${edition.shortTitle}»").join(", ");
    return [
      Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Text(
          "Счёт глав и стихов — канонический, славянский. "
          "В $names часть стихов напечатана под другими номерами.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ];
  }

  /// Переход к соседним главам — внизу, а не только в шапке: читатель дочитал
  /// главу и хочет дальше, и гнать его прокруткой обратно наверх значит повторить
  /// ошибку, которую уже исправляли оглавлением длинных текстов.
  Widget _navigation(BuildContext context) {
    final total = chaptersInBook;
    final hasPrevious = widget.chapter > 1;
    final hasNext = total == null || widget.chapter < total;

    if (!hasPrevious && !hasNext) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (hasPrevious)
            TextButton(
              onPressed: () => _openChapter(widget.chapter - 1),
              child: Text("← Глава ${widget.chapter - 1}"),
            )
          else
            const SizedBox.shrink(),
          if (hasNext)
            TextButton(
              onPressed: () => _openChapter(widget.chapter + 1),
              child: Text("Глава ${widget.chapter + 1} →"),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
