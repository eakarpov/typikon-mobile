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
import 'package:typikon/store/reading_progress.dart';
import 'package:typikon/store/rule_marks.dart';
import 'package:typikon/utils/bible_style.dart';
import 'package:typikon/utils/reading_style.dart';
import 'package:typikon/utils/script_convert.dart';

/// Аргумент маршрута `/psalter/kathisma`: прежде — голое число (1..20 или
/// 151), с поминальным режимом — строка `<число>|d` («17|d» — 17-я кафизма
/// с именами усопших на славах). Собирается [kathismaRouteArgument].
class KathismaRouteTarget {
  final int number;
  final bool departed;

  const KathismaRouteTarget(this.number, this.departed);
}

/// Строковый аргумент маршрута; обычная кафизма — прежнее голое число,
/// чтобы старые ссылки и тесты не переучивать.
Object kathismaRouteArgument(int number, {bool departed = false}) =>
    departed ? "$number|d" : number;

/// Разбор аргумента маршрута. Негодный — `null`: не открыть кафизму
/// лучше, чем открыть чужую.
KathismaRouteTarget? parseKathismaRouteArgument(Object? raw) {
  if (raw is int) {
    return isKathismaNumber(raw) || raw == psalm151
        ? KathismaRouteTarget(raw, false)
        : null;
  }
  if (raw is String) {
    final parts = raw.split("|");
    if (parts.length > 2) return null;
    final number = int.tryParse(parts.first.trim());
    if (number == null) return null;
    if (!isKathismaNumber(number) && number != psalm151) return null;
    final departed = parts.length == 2 && parts[1].trim() == "d";
    return KathismaRouteTarget(number, departed);
  }
  return null;
}

/// Часть кафизмы, какой она идёт на экран: псалом целиком (обычные кафизмы)
/// или срез стихов одного псалма (17-я кафизма делится стихами 118-го).
/// [breakAfter] — разделитель, который ставится ПОСЛЕ части: между статьями
/// (`statiaBreak`, у 17-й — `psalmodyEnd`), у последней статьи — `null`:
/// после неё идёт окончание кафизмы целиком.
class _Part {
  final int psalm;
  final int? verseFrom;
  final int? verseTo;
  final String? breakAfter;

  const _Part(this.psalm, {this.verseFrom, this.verseTo, this.breakAfter});
}

/// Чтение кафизмы одним скроллом: псалмы диапазона подряд, между статьями —
/// разделитель, в конце — окончание кафизмы. Номер 1..20 — кафизма; 151 —
/// дополнительный псалом (без разделителей и окончания).
///
/// Поминальный режим ([departed]): после всякой славы — блок молитв с именами
/// из помянника (об усопших после «Слава», о живых после «И ныне»). Кафизма
/// при этом читается как обычно: молитвы — прибавка, а не условие, и ни одна
/// плашка (войти / нет сети / имена не обновлены) её не останавливает.
///
/// Главы грузятся одним списком futures (`Future.wait`), тексты склеиваются
/// готовым `VerseListView`. Позиция читателя — доля скролла в общем
/// хранилище прогресса (`psalter:kathisma:<n>`), дочитанная кафизма запись
/// стирает само хранилище.
class KathismaPage extends StatefulWidget {
  final int number;

  /// Поминальное чтение: молитвы с именами усопших и живых на славах.
  final bool departed;

  /// Подменяется тестами; в приложении — `getBibleChapter('psaltir', n)`.
  final Future<BibleChapter> Function(int chapter)? loadChapter;

  /// Подменяется тестами; в приложении — `loadPsalterNamedPrayers`.
  final Future<PsalterNamedPrayers> Function(String gender)? prayersLoader;

  const KathismaPage({
    super.key,
    required this.number,
    this.departed = false,
    this.loadChapter,
    this.prayersLoader,
  });

  @override
  State<KathismaPage> createState() => _KathismaPageState();
}

class _KathismaPageState extends State<KathismaPage> {
  late final List<_Part> _parts;
  late Future<Map<int, BibleChapter>> _chapters;

  /// Молитвы с именами: запрос разовый, на открытие. `null` — не поминальный
  /// режим, и грузить нечего.
  Future<PsalterNamedPrayers>? _prayers;

  final ScrollController _scrollController = ScrollController();
  Timer? _persistDebounce;
  bool _resumeBannerShown = false;

  /// Доля прокрутки на последнем движении: в `dispose` спросить её уже
  /// не у кого, дети снимаются с дерева раньше родителя.
  double? _lastFraction;

  // MaterialBanner живёт в ScaffoldMessenger выше MaterialApp и переживает
  // уход со страницы: снимаем его в dispose, а ссылку берём заранее.
  ScaffoldMessengerState? _messenger;
  bool _bannerVisible = false;

  String get _progressId => kathismaProgressId(widget.number);

  bool get _isKathisma => isKathismaNumber(widget.number);

  @override
  void initState() {
    super.initState();
    _parts = _buildParts(widget.number);
    _scrollController.addListener(_onScroll);
    _load();
    if (widget.departed) _prayers = _loadPrayers();
    _checkResumeProgress();
  }

  /// Род молящегося — из того же ключа, что и последования (`rule_gender`):
  /// молитва о живых спрашивает «раба» или «рабы» по нему одному.
  Future<PsalterNamedPrayers> _loadPrayers() async {
    final gender = await ruleGender();
    final loader = widget.prayersLoader;
    if (loader != null) return loader(gender);
    return loadPsalterNamedPrayers(gender: gender);
  }

  List<_Part> _buildParts(int number) {
    if (number == psalm151) {
      return const <_Part>[_Part(psalm151)];
    }
    final statii = kathismaStatii(number);
    return <_Part>[
      for (var i = 0; i < statii.length; i++)
        if (statii[i].isVerseBased)
          _Part(
            statii[i].firstPsalm,
            verseFrom: statii[i].firstVerse,
            verseTo: statii[i].lastVerse,
            breakAfter: i < statii.length - 1 ? psalmodyEnd : null,
          )
        else
          for (var psalm = statii[i].firstPsalm;
              psalm <= statii[i].lastPsalm;
              psalm++)
            _Part(
              psalm,
              breakAfter: psalm == statii[i].lastPsalm && i < statii.length - 1
                  ? statiaBreak
                  : null,
            ),
    ];
  }

  void _load() {
    _chapters = _loadChapters();
  }

  Future<Map<int, BibleChapter>> _loadChapters() async {
    final loader =
        widget.loadChapter ?? (int psalm) => getBibleChapter("psaltir", psalm);
    final psalms = _parts.map((part) => part.psalm).toSet().toList()..sort();
    final loaded = await Future.wait(psalms.map(loader));
    return Map<int, BibleChapter>.fromIterables(psalms, loaded);
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
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 2), _persistProgressNow);
  }

  void _persistProgressNow() {
    final fraction = _lastFraction;
    // Не прокручивали — записывать нечего, и прежнюю запись не затираем.
    if (fraction == null) return;
    saveReadingProgress(_progressId, fraction, name: kathismaProgressName(widget.number));
  }

  Future<void> _checkResumeProgress() async {
    final progress = await getReadingProgress(_progressId);
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
    _messenger?.showMaterialBanner(
      MaterialBanner(
        content: const Text("Вы уже читали эту кафизму. Продолжить с места, где остановились?"),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              _hideResumeBanner();
              clearReadingProgress(_progressId);
            },
            child: const Text("Сначала"),
          ),
          TextButton(
            onPressed: () {
              _hideResumeBanner();
              _resumeTo(fraction);
            },
            child: const Text("Продолжить"),
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

  void _retry() {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isKathisma ? kathismaTitle(widget.number) : "Псалом 151 (дополнительный)",
          style: const TextStyle(fontFamily: "OldStandard", fontSize: 18.0),
        ),
      ),
      body: PinchZoom(child: Container(
        color: readingBackgroundColor(context),
        child: ReadingColumn(child: FutureBuilder<Map<int, BibleChapter>>(
          future: _chapters,
          builder: (context, future) {
            if (future.hasError) return _error(future.error);
            if (!future.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _content(context, future.data!);
          },
        )),
      )),
    );
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
    // Сообщение сервера точнее нашего: у честного 404 («В этих изданиях
    // такой главы нет») свой текст — например, если дополнительного
    // псалма 151 издание не печатает.
    if (error is ApiNotFoundException) {
      return ApiErrorView(error: error, message: error.message);
    }
    return ApiErrorView(
      error: error,
      message: "Не удалось загрузить кафизму.",
      offlineMessage: "Эта кафизма ещё не открывалась, а сети сейчас нет.",
      onRetry: _retry,
    );
  }

  Widget _content(BuildContext context, Map<int, BibleChapter> chapters) {
    // Поминальный режим: молитвы подгружаются своим будущим, и чтение
    // перестраивается, когда они пришли. Сама кафизма от них не зависит.
    if (widget.departed) {
      return FutureBuilder<PsalterNamedPrayers>(
        future: _prayers,
        builder: (context, snapshot) =>
            _buildReading(context, chapters, snapshot.data),
      );
    }
    return _buildReading(context, chapters, null);
  }

  Widget _buildReading(
    BuildContext context,
    Map<int, BibleChapter> chapters,
    PsalterNamedPrayers? prayers,
  ) {
    final settings = StoreProvider.of<AppState>(context).state.settings;
    final first = chapters.values.first;
    final edition = first.editions.isEmpty ? null : first.editions.first;
    final fontFamily = bibleFontFamily(edition?.language ?? "");
    final script = bibleScript(edition?.language);
    final fontSize = settings.fontSize.toDouble();

    Widget? lastPsalmCaption;
    final blocks = <Widget>[];
    var breakIndex = 0;
    for (final part in _parts) {
      final chapter = chapters[part.psalm];
      if (chapter == null) continue;
      var verses = chapter.versesFor(0);
      if (part.verseFrom != null || part.verseTo != null) {
        verses = verses
            .where((v) =>
                v.verse >= (part.verseFrom ?? 1) &&
                v.verse <= (part.verseTo ?? 1 << 30))
            .toList();
      }
      if (verses.isEmpty) continue;
      if (lastPsalmCaption?.key != ValueKey<int>(part.psalm)) {
        final caption = Padding(
          key: ValueKey<int>(part.psalm),
          padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
          child: Text(
            "Псалом ${part.psalm}",
            style: TextStyle(
              fontFamily: "OldStandard",
              fontSize: fontSize * 0.85,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        );
        lastPsalmCaption = caption;
        blocks.add(caption);
      }
      blocks.add(VerseListView(
        verses: verses,
        fontSize: fontSize,
        fontFamily: fontFamily,
        script: script,
      ));
      final breakText = part.breakAfter;
      if (breakText != null) {
        blocks.add(_BreakLine(breakText));
        if (prayers != null) {
          // Разделитель один на обе половины («Слава, и ныне:»), поэтому обе
          // молитвы — блоком: сначала об усопших, затем о живых. Плашку
          // показывает только первый блок: трижды повторённая, она задушила бы
          // само чтение.
          blocks.add(NamedPrayerBlock(prayers, showNotice: breakIndex == 0));
          breakIndex++;
        }
      }
    }
    if (_isKathisma && blocks.isNotEmpty) {
      blocks.add(_BreakLine(kathismaEnd));
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ...blocks,
          ScriptCaveat(source: script),
        ],
      ),
    );
  }
}

/// Разделитель между статьями и окончание кафизмы: по книжному обычаю эти
/// формулы стоят отдельной строкой посреди стихословия.
class _BreakLine extends StatelessWidget {
  final String text;

  const _BreakLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: "OldStandard",
            fontSize: readingFontSize(context) * 0.9,
            fontStyle: FontStyle.italic,
            color: readingTextColor(context),
          ),
        ),
      ),
    );
  }
}
