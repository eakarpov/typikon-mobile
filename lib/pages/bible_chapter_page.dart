import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../apiMapper/bible.dart';
import '../apiMapper/v2/errors.dart';
import '../components/api_error_view.dart';
import '../components/chapter_grid.dart';
import '../components/verse_list.dart';
import '../dto/bible.dart';
import '../store/models/models.dart';
import '../utils/bible_editions.dart';
import '../utils/bible_route.dart';
import '../utils/bible_style.dart';

/// Глава Библии.
///
/// В этой итерации показывается одно издание сплошным текстом через готовый
/// `VerseListView`. Параллельный вид и выбор изданий — следующим шагом; выбор
/// пока разрешается сам: эталонное издание, то есть та нумерация, которой
/// записаны зачала Типикона.
class BibleChapterPage extends StatefulWidget {
  const BibleChapterPage(
    context, {
    super.key,
    required this.canonId,
    required this.chapter,
  });

  final String canonId;
  final int chapter;

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

  @override
  void initState() {
    super.initState();
    _load();
    _loadChapterCount();
  }

  void _load() {
    chapter = _loadChapter();
  }

  Future<BibleChapter> _loadChapter() async {
    // Список изданий нужен, чтобы узнать эталон, а не гадать про `cs-eliz`.
    // Не пришёл — идём без параметра: сервер поймёт это как «все публичные»,
    // и это лучше пустого экрана.
    BibleEditionList editions = const BibleEditionList([]);
    try {
      editions = await getBibleEditions();
    } catch (_) {}

    return getBibleChapter(
      widget.canonId,
      widget.chapter,
      editions: resolveEditionCodes(const [], editions),
    );
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
    final edition = data.editions.isEmpty ? null : data.editions.first;
    final verses = data.versesFor(0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (verses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Text("В этом издании главы нет."),
            )
          else
            VerseListView(
              verses: verses,
              fontSize: fontSize,
              fontFamily: bibleFontFamily(edition?.language ?? ""),
            ),
          if (edition != null) _numberingNote(context, edition),
          _navigation(context),
        ],
      ),
    );
  }

  /// Оговорка про счёт.
  ///
  /// Показывается только там, где она нужна: у эталона обе нумерации совпадают,
  /// а вот греческие Притчи открываются в славянском счёте, и читатель не найдёт
  /// своей 24-й главы там, где привык. Замолчать это нельзя — режим счёта самого
  /// издания в первой итерации не сделан, и цену отказа надо назвать.
  Widget _numberingNote(BuildContext context, BibleEdition edition) {
    if (edition.isReference) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Text(
        "Счёт глав и стихов — канонический, славянский. "
        "В издании «${edition.shortTitle}» часть стихов напечатана под другими номерами.",
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
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
