import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import "package:google_fonts/google_fonts.dart";
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_saver_ffi/file_saver_ffi.dart';
import "package:path_provider/path_provider.dart";
import 'package:epub_pro/epub_pro.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:typikon/main.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:redux/redux.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import "package:typikon/components/api_error_view.dart";
import "package:typikon/utils/fb2.dart";
import "package:typikon/components/fusion_text.dart";
import "package:typikon/components/table_of_contents.dart";
import "package:typikon/components/verse_list.dart";
import "package:typikon/components/selection_menu.dart";
import "package:typikon/components/report_error_sheet.dart";
import 'package:typikon/store/models/models.dart';
import 'package:typikon/store/reading_progress.dart';
import 'package:typikon/dto/book.dart';
import 'package:typikon/dto/calendar.dart' show PericopeVerse;
import 'package:typikon/dto/text.dart';
import 'package:typikon/dto/verse.dart';
import 'package:typikon/dto/user_note.dart';
import 'package:typikon/dto/dneslov/images.dart';
import '../apiMapper/reading.dart';
import '../apiMapper/verses.dart';
import '../apiMapper/user_notes.dart';
import "../apiMapper/dneslov/images.dart";

class TextPage extends StatefulWidget {
  final String id;

  const TextPage(context, {super.key, required this.id});

  @override
  State<TextPage> createState() => _TextPageState();
}

class _TextPageState extends State<TextPage> with WidgetsBindingObserver {
  late Future<Reading> reading;
  late Future<DneslovImageListD> dneslovImages;
  Future<VerseList>? verses;

  // "Читать целиком" со страницы зачала кодирует начальную главу как
  // суффикс "$textId#$chapter" в id маршрута — так не пришлось менять
  // сигнатуру всех 8 существующих pushNamed(context, "/reading", ...).
  late final String _realId;
  int? _initialChapter;
  final Map<int, GlobalKey> _chapterKeys = {};

  List<UserNote> _userNotes = [];

  bool isFavourite = false;

  final ScrollController _scrollController = ScrollController();
  Timer? _persistDebounce;
  bool _resumeBannerShown = false;

  // MaterialBanner живёт в ScaffoldMessenger, а тот — выше MaterialApp, то есть
  // переживает уход со страницы: не нажав ни "Сначала", ни "Продолжить",
  // пользователь уносил баннер с собой на следующий экран. Снимаем его в
  // dispose, а ссылку на messenger берём заранее — в dispose искать его по
  // дереву уже поздно.
  ScaffoldMessengerState? _messenger;
  bool _bannerVisible = false;

  GlobalKey _chapterKey(int chapter) => _chapterKeys.putIfAbsent(chapter, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    final parts = widget.id.split('#');
    _realId = parts[0];
    _initialChapter = parts.length > 1 ? int.tryParse(parts[1]) : null;
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadReading();
    _loadUserNotes();
    SharedPreferences.getInstance().then((prefs){
      List<String>? liked = prefs.getStringList("favourites") ?? [];
      if (liked.contains(_realId)) {
        setState(() {
          isFavourite = true;
        });
      }
    });
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

  void _onScroll() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 2), _persistProgressNow);
  }

  void _persistProgressNow() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    if (maxExtent <= 0) return;
    final fraction = (position.pixels / maxExtent).clamp(0.0, 1.0);
    saveReadingProgress(_realId, fraction);
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

  void _loadReading() {
    _resumeBannerShown = false;
    reading = getText(_realId);
    reading.then((value) {
      if (value.dneslovId != null) {
        dneslovImages = fetchDneslovImagesD(value.dneslovId!);
      }
      if (value.isVerses) {
        final versesFuture = getVerses(_realId);
        verses = versesFuture;
        versesFuture.then((list) {
          if (!mounted || _initialChapter == null) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final targetContext = _chapterKey(_initialChapter!).currentContext;
            if (targetContext != null) {
              Scrollable.ensureVisible(
                targetContext,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: 0.05,
              );
            }
          });
        });
        setState(() {});
      } else {
        _checkResumeProgress();
      }
    });
  }

  void _retry() {
    setState(_loadReading);
  }

  void _loadUserNotes() {
    if (!StoreProvider.of<AppState>(context).state.auth.isSignedIn) return;
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

  Widget imageCard(value) {
    return Image(
      image: NetworkImage(value),
    );
  }

  void onLike() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? liked = prefs.getStringList("favourites");
    if (liked == null) {
      List<String> newLiked = [];
      newLiked.add(_realId);
      prefs.setStringList("favourites", newLiked);
      setState(() {
        isFavourite = true;
      });
    } else {
      if (liked.contains(_realId)) {
        List<String> newLiked = liked.where((e) => e != _realId).toList();
        prefs.setStringList("favourites", newLiked);
        setState(() {
          isFavourite = false;
        });
      } else {
        liked.add(_realId);
        prefs.setStringList("favourites", liked);
        setState(() {
          isFavourite = true;
        });
      }
    }
  }

  List<TocEntry> _chapterToc(List<int> chapters) {
    return chapters.map((c) => TocEntry(
      title: "Глава $c",
      anchorKey: _chapterKey(c),
    )).toList();
  }

  Widget _buildVerses(BuildContext context) {
    return FutureBuilder<VerseList>(
      future: verses,
      builder: (context, future) {
        if (future.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text("Не удалось загрузить текст Библии."),
          );
        }
        if (!future.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final byChapter = future.data!.byChapter;
        final chapters = byChapter.keys.toList()..sort();
        final fontSize = StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble();
        return SelectionMenu(
          enabled: StoreProvider.of<AppState>(context).state.auth.isSignedIn,
          textId: _realId,
          containers: future.data!.list.map((v) => TextContainer.verse(
            chapter: v.chapter, verse: v.verse, text: "${v.content} ",
          )).toList(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: chapters.map((chapter) {
            final chapterVerses = byChapter[chapter]!
                .map((v) => PericopeVerse(chapter: v.chapter, verse: v.verse, content: v.content))
                .toList();
            return Padding(
              key: _chapterKey(chapter),
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Глава $chapter", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  VerseListView(
                    verses: chapterVerses,
                    fontSize: fontSize,
                    fontFamily: "Monomakh",
                    notes: _userNotes,
                    onTapNote: _onTapUserNote,
                  ),
                ],
              ),
            );
          }).toList(),
          ),
        );
      },
    );
  }

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
                    child: Text("РУ", style: TextStyle(color: Colors.white),),
                  ),
                  if (future.data!.link != null) TextButton(
                    onPressed: () => onClick(future.data!.link as String),
                    child: Text("ЦС", style: TextStyle(color: Colors.white),),
                  ),
                  if (future.data!.dneslovId != null) IconButton(
                      onPressed: () => Navigator.pushNamed(context, "/saints", arguments: future.data!.dneslovId),
                      icon: Icon(Icons.person, color: Colors.white),
                  ),
                  if (future.data!.bookId != null) IconButton(
                      onPressed: () => Navigator.pushNamed(context, "/library", arguments: future.data!.bookId),
                      icon: Icon(Icons.menu_book, color: Colors.white),
                  ),
                  if (future.data!.dayId != null) IconButton(
                      onPressed: () => Navigator.pushNamed(context, "/days", arguments: future.data!.dayId),
                      icon: Icon(Icons.calendar_month, color: Colors.white),
                  ),
                ],
              );
            }
            return Row(children: []);
          }),
        ),
        actions: <Widget>[
          FutureBuilder<VerseList>(
            future: verses,
            builder: (context, future) {
              if (!future.hasData || future.data!.list.isEmpty) return const SizedBox.shrink();
              final chapters = future.data!.byChapter.keys.toList()..sort();
              return IconButton(
                icon: Icon(Icons.toc, color: Colors.white),
                tooltip: "Главы",
                onPressed: () => showTableOfContents(context, _chapterToc(chapters)),
              );
            },
          ),
          IconButton(
              onPressed: onLike,
              icon: isFavourite ? Icon(
                Icons.favorite,
                color: Colors.pink,
              ) : Icon(
                Icons.favorite_outline,
              )
          ),
          FutureBuilder<Reading>(
            future: reading,
            builder: (context, future) {
              if (future.hasData) {
                return IconButton(
                  icon: Icon(Icons.file_download, color: Colors.white),
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
      body: Container(
        color: StoreProvider.of<AppState>(context).state.settings.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<Reading>(
          future: reading,
          builder: (context, future) {
            if (future.hasData) {
              String content = future.data!.content;
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
                      future.data!.isVerses ? _buildVerses(context) : (
                        future.data!.newUi ? (
                          SizedBox(
                            height: 350.0,
                            child: Markdown(
                              data: content,
                            ),
                          )
                        ) : (
                            SelectionMenu(
                              enabled: StoreProvider.of<AppState>(context).state.auth.isSignedIn,
                              textId: _realId,
                              containers: content.split("\n\n").asMap().entries.map((entry) =>
                                  TextContainer.paragraph(paragraphIndex: entry.key, text: entry.value)
                              ).toList(),
                              child: Column(
                                children: content.split("\n\n").asMap().entries.map((entry) =>
                                    FusionTextWidgets(
                                      text: entry.value,
                                      footnotes: future.data?.footnotes??[],
                                      fontFamily: future.data!.csSource ? "Monomakh" : "OldStandard",
                                      notes: _userNotes.where((n) =>
                                          n.selection.type == 'paragraph' && n.selection.paragraphIndex == entry.key
                                      ).toList(),
                                      onTapNote: _onTapUserNote,
                                    ),
                                ).toList(),
                              ),
                            )
                        )
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
        ),
      ),
    );
  }
}