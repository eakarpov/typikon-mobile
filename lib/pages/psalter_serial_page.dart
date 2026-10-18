import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:typikon/apiMapper/bible.dart';
import 'package:typikon/apiMapper/v2/errors.dart';
import 'package:typikon/components/api_error_view.dart';
import 'package:typikon/components/named_prayer_block.dart';
import 'package:typikon/components/pinch_zoom.dart';
import 'package:typikon/components/script_toggle.dart';
import 'package:typikon/components/verse_list.dart';
import 'package:typikon/domain/psalter.dart';
import 'package:typikon/dto/bible.dart';
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/psalter_prayers.dart';
import 'package:typikon/store/psalter_serial_bookmark.dart';
import 'package:typikon/store/rule_marks.dart';
import 'package:typikon/utils/bible_style.dart';
import 'package:typikon/utils/reading_style.dart';
import 'package:typikon/utils/script_convert.dart';

/// Аргумент маршрута `/psalter/serial`: прежде — `null` (с закладки) или
/// номер псалма (листание), с поминальным режимом — строка: `"d"` (с закладки,
/// о усопших) или `"<псалом>|d"` («5|d»). Собирается [serialRouteArgument].
class SerialRouteTarget {
  final int? chapter;
  final bool departed;

  const SerialRouteTarget(this.chapter, this.departed);
}

/// Строковый аргумент поминального режима; обычное листание — прежнее голое
/// число, чтобы не переучивать старые переходы.
Object? serialRouteArgument({int? chapter, bool departed = false}) {
  if (chapter == null) return departed ? "d" : null;
  return departed ? "$chapter|d" : chapter;
}

/// Разбор аргумента маршрута. Негодный — `null`: не открыть лучше, чем
/// открыть не то чтение.
SerialRouteTarget? parseSerialRouteArgument(Object? raw) {
  if (raw == null) return const SerialRouteTarget(null, false);
  if (raw is int) return SerialRouteTarget(raw, false);
  if (raw is String) {
    final parts = raw.split("|");
    if (parts.length > 2) return null;
    final head = parts.first.trim();
    // «d» одно — поминальный режим с закладки.
    if (parts.length == 1 && head == "d") {
      return const SerialRouteTarget(null, true);
    }
    final chapter = int.tryParse(head);
    if (chapter == null) return null;
    final departed = parts.length == 2 && parts[1].trim() == "d";
    return SerialRouteTarget(chapter, departed);
  }
  return null;
}

/// «Псалтирь подряд» — непрерывное чтение всей Псалтири: псалом за псалмом,
/// от первого до сто пятьдесят первого.
///
/// Без аргумента открывается там, где читатель остановился, — закладка
/// своего вида: {глава, стих} в `psalter_serial_bookmark.dart`. С аргументом
/// (число) открывает названный псалом — так листают кнопкой «Псалом N →»
/// внизу. После 151-го — честный финал: «Псалтирь прочитана» и сброс
/// закладки по кнопке «Начать сначала».
class PsalterSerialPage extends StatefulWidget {
  /// Псалом, с которого открываем. `null` — с закладки, а без неё с 1-го.
  final int? chapter;

  /// Поминальное чтение (Неусыпаемая Псалтирь): молитвы с именами вставляются
  /// после границ кафизм, а не после каждого псалма.
  final bool departed;

  /// Подменяется тестами; в приложении — `getBibleChapter('psaltir', n)`.
  final Future<BibleChapter> Function(int chapter)? loadChapter;

  /// Подменяется тестами; в приложении — `loadPsalterNamedPrayers`.
  final Future<PsalterNamedPrayers> Function(String gender)? prayersLoader;

  const PsalterSerialPage({
    super.key,
    this.chapter,
    this.departed = false,
    this.loadChapter,
    this.prayersLoader,
  });

  @override
  State<PsalterSerialPage> createState() => _PsalterSerialPageState();
}

class _PsalterSerialPageState extends State<PsalterSerialPage> {
  /// Открытый псалом. Разрешается асинхронно: без аргумента ждём закладку.
  int? _chapter;

  /// Стих закладки, к которому прокручиваем при открытии. `null` — с начала.
  int? _initialVerse;

  Future<BibleChapter>? _future;

  /// Молитвы с именами: запрос разовый, на открытие. `null` — не поминальный
  /// режим, и грузить нечего.
  Future<PsalterNamedPrayers>? _prayers;

  final ScrollController _scrollController = ScrollController();
  Timer? _saveDebounce;

  /// Последний загруженный псалом: закладку считаем по его стихам.
  BibleChapter? _loaded;

  double? _lastFraction;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.departed) _prayers = _loadPrayers();
    _init();
  }

  /// Род молящегося — из того же ключа, что и последования (`rule_gender`).
  Future<PsalterNamedPrayers> _loadPrayers() async {
    final gender = await ruleGender();
    final loader = widget.prayersLoader;
    if (loader != null) return loader(gender);
    return loadPsalterNamedPrayers(gender: gender);
  }

  Future<void> _init() async {
    final int target;
    final int verse;
    if (widget.chapter != null) {
      // Листнули кнопкой «Псалом N →»: новый псалом с начала.
      target = widget.chapter!;
      verse = 1;
    } else {
      // Открыли «Подряд» из списка — продолжаем с закладки.
      final bookmark = await getPsalterSerialBookmark();
      target = bookmark?.chapter ?? 1;
      verse = bookmark?.verse ?? 1;
    }
    if (!mounted) return;
    setState(() {
      _chapter = target;
      _initialVerse = widget.chapter == null ? verse : null;
      _future = _load(target);
    });
  }

  Future<BibleChapter> _load(int chapter) async {
    final loader =
        widget.loadChapter ?? (int psalm) => getBibleChapter("psaltir", psalm);
    final data = await loader(chapter);
    _loaded = data;
    _scrollToInitialVerse(data);
    return data;
  }

  void _scrollToInitialVerse(BibleChapter data) {
    final verse = _initialVerse;
    if (verse == null || verse <= 1) return;
    final verses = data.versesFor(0);
    if (verses.length < 2) return;
    final index = verses.indexWhere((v) => v.verse >= verse);
    if (index <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo((index / (verses.length - 1)) * maxExtent);
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveBookmarkNow();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      if (position.maxScrollExtent > 0) {
        _lastFraction = (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
      }
    }
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), _saveBookmarkNow);
  }

  void _saveBookmarkNow() {
    final fraction = _lastFraction;
    final chapter = _chapter;
    final data = _loaded;
    if (fraction == null || chapter == null || data == null) return;
    final verses = data.versesFor(0);
    if (verses.isEmpty) return;
    final index = (fraction * (verses.length - 1)).round().clamp(0, verses.length - 1);
    savePsalterSerialBookmark(chapter, verses[index].verse);
  }

  void _openChapter(int chapter) {
    // Листание сохраняет режим: поминальное чтение не возвращается в
    // обычное одним нажатием «Псалом N →».
    Navigator.pushReplacementNamed(
      context,
      "/psalter/serial",
      arguments: serialRouteArgument(chapter: chapter, departed: widget.departed),
    );
  }

  void _retry() {
    final chapter = _chapter;
    if (chapter == null) return;
    setState(() {
      _future = _load(chapter);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          chapter == null || chapter > psalm151
              ? "Псалтирь подряд"
              : "Псалтирь подряд${widget.departed ? " · о усопших" : ""} · Псалом $chapter",
          style: const TextStyle(fontFamily: "OldStandard", fontSize: 18.0),
        ),
      ),
      body: chapter == null
          ? const Center(child: CircularProgressIndicator())
          // После 151-го — честный финал; сам 151-й читается как все.
          : chapter > psalm151
              ? _finale(context)
              : _reading(context, chapter),
    );
  }

  /// Финал: всё прочитано. Закладку сбрасывает только кнопка — сама она не
  /// стирается: вдруг человек открыл финал случайным листанием назад.
  Widget _finale(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.menu_book, size: 56.0),
          const SizedBox(height: 16.0),
          const Text(
            "Псалтирь прочитана",
            style: TextStyle(fontFamily: "OldStandard", fontSize: 20.0),
          ),
          const SizedBox(height: 8.0),
          const Text("Вы дочитали всю Псалтирь подряд — от Пс 1 до Пс 151."),
          const SizedBox(height: 24.0),
          FilledButton(
            onPressed: () async {
              await clearPsalterSerialBookmark();
              if (!mounted) return;
              _openChapter(1);
            },
            child: const Text("Начать сначала"),
          ),
        ],
      ),
    );
  }

  Widget _reading(BuildContext context, int chapter) {
    return PinchZoom(child: Container(
      color: readingBackgroundColor(context),
      child: ReadingColumn(child: FutureBuilder<BibleChapter>(
        future: _future,
        builder: (context, future) {
          if (future.hasError) return _error(future.error);
          if (!future.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _chapterView(context, future.data!, chapter);
        },
      )),
    ));
  }

  Widget _error(Object? error) {
    if (error is ApiRateLimitedException) {
      return ApiErrorView(
        error: error,
        message: error.message,
        hint: error.hint,
        onRetry: _retry,
      );
    }
    if (error is ApiNotFoundException) {
      return ApiErrorView(error: error, message: error.message);
    }
    return ApiErrorView(
      error: error,
      message: "Не удалось загрузить псалом.",
      offlineMessage: "Этот псалом ещё не открывался, а сети сейчас нет.",
      onRetry: _retry,
    );
  }

  Widget _chapterView(BuildContext context, BibleChapter data, int chapter) {
    // Поминальный режим: молитвы подгружаются своим будущим, и чтение
    // перестраивается, когда они пришли. Сам псалом от них не зависит.
    if (widget.departed) {
      return FutureBuilder<PsalterNamedPrayers>(
        future: _prayers,
        builder: (context, snapshot) =>
            _chapterScroll(context, data, chapter, snapshot.data),
      );
    }
    return _chapterScroll(context, data, chapter, null);
  }

  Widget _chapterScroll(
    BuildContext context,
    BibleChapter data,
    int chapter,
    PsalterNamedPrayers? prayers,
  ) {
    final settings = StoreProvider.of<AppState>(context).state.settings;
    final edition = data.editions.isEmpty ? null : data.editions.first;
    final fontFamily = bibleFontFamily(edition?.language ?? "");
    final script = bibleScript(edition?.language);
    final verses = data.versesFor(0);

    // Граница кафизмы — после её последнего псалма (в «подряд» кафизма
    // не делится на славы, и молитвы встают одним блоком на границе целиком).
    final boundary = widget.departed && endsKathisma(chapter) && prayers != null;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          VerseListView(
            verses: verses,
            fontSize: settings.fontSize.toDouble(),
            fontFamily: fontFamily,
            script: script,
          ),
          if (boundary) NamedPrayerBlock(prayers),
          ScriptCaveat(source: script),
          _nextButton(context, chapter),
        ],
      ),
    );
  }

  Widget _nextButton(BuildContext context, int chapter) {
    final next = chapter + 1;
    // До Пс 151 включительно — дальше честный финал.
    final label = next > psalm151 ? "Завершить чтение →" : "Псалом $next →";
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TextButton(
            onPressed: () => _openChapter(next),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
