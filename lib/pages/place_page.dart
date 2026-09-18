import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:typikon/apiMapper/places.dart';
import 'package:typikon/components/api_error_view.dart';
import 'package:typikon/components/table_of_contents.dart';
import 'package:typikon/dto/pericope.dart';
import 'package:typikon/dto/place.dart';
import 'package:typikon/dto/place_mentions.dart';
import 'package:typikon/utils/bible_route.dart';
import 'package:typikon/utils/place_labels.dart';

/// МЕСТО: имена по эпохам, отождествления, где названо в Писании, в чтениях и в
/// песнопениях, к чьим памятям.
///
/// **Две загрузки врозь.** Карточка — один запрос, упоминания — шесть сводов и
/// обращение к певческому корпусу; вторая упадёт первой, и её отказ не должен
/// уносить с собой имена и описание. Тот же приём, что в досье святого.
///
/// **Свиток с оглавлением, а не вкладки.** Разделы читаются как одна статья в
/// заданном порядке; вкладки в досье святого стоят потому, что там три
/// независимых источника, а здесь — один рассказ.
///
/// **Карты нет.** Точка показывается строкой и открывается в том картографическом
/// приложении, что стоит у человека. Своей карты в приложении нет вовсе — это
/// отдельная работа, и без неё раздел полон.
class PlacePage extends StatefulWidget {
  final String id;

  const PlacePage(BuildContext? context, {super.key, required this.id});

  @override
  State<PlacePage> createState() => _PlacePageState();
}

class _PlacePageState extends State<PlacePage> {
  PlaceDetail? _place;
  Object? _placeError;
  bool _placeLoading = true;

  PlaceMentions? _mentions;
  Object? _mentionsError;
  bool _mentionsLoading = true;

  /// Стихи раскрытых книг: по книге, как раскрывает читатель.
  final Map<String, List<PlaceVerse>> _verses = {};
  final Set<String> _loadingBooks = {};

  final Map<String, GlobalKey> _anchors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _placeLoading = true;
    _mentionsLoading = true;
    _placeError = null;
    _mentionsError = null;

    getPlace(widget.id).then((place) {
      if (!mounted) return;
      setState(() {
        _place = place;
        _placeLoading = false;
      });
    }).catchError((error) {
      if (!mounted) return;
      setState(() {
        _placeError = error;
        _placeLoading = false;
      });
    });

    getPlaceMentions(widget.id).then((mentions) {
      if (!mounted) return;
      setState(() {
        _mentions = mentions;
        _mentionsLoading = false;
      });
    }).catchError((error) {
      if (!mounted) return;
      setState(() {
        _mentionsError = error;
        _mentionsLoading = false;
      });
    });
  }

  void _retry() => setState(_load);

  Future<void> _openBook(ScriptureBookRef book) async {
    if (_verses.containsKey(book.canonId) || _loadingBooks.contains(book.canonId)) return;

    setState(() => _loadingBooks.add(book.canonId));
    try {
      final page = await getPlaceScripture(widget.id, book: book.canonId);
      if (!mounted) return;
      setState(() {
        _verses[book.canonId] = page.items;
        _loadingBooks.remove(book.canonId);
      });
    } catch (_) {
      if (!mounted) return;
      // Молча: книга остаётся свёрнутой, и её можно раскрыть заново. Отказ на
      // одной книге не повод рушить всю страницу.
      setState(() => _loadingBooks.remove(book.canonId));
    }
  }

  GlobalKey _anchor(String name) => _anchors.putIfAbsent(name, () => GlobalKey());

  void _openVerse(PlaceVerse verse) {
    Navigator.pushNamed(
      context,
      "/bible",
      arguments: bibleRouteArgument(
        verse.canonId,
        chapter: verse.chapter,
        // Отрезок в один стих: глава откроется на нём и подсветит его.
        ranges: [
          PericopeRange(
            chapterFrom: verse.chapter,
            verseFrom: verse.verse,
            chapterTo: verse.chapter,
            verseTo: verse.verse,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = _place;
    final sections = place == null ? <_SectionSpec>[] : _sections(place);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          place?.name ?? (_placeLoading ? "Место" : "Ошибка загрузки"),
          style: const TextStyle(fontFamily: "OldStandard"),
        ),
        actions: [
          if (sections.length > 1)
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: "Содержание",
              onPressed: () => showTableOfContents(
                context,
                sections
                    .map((section) => TocEntry(
                          title: section.title,
                          anchorKey: _anchor(section.title),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
      body: _body(sections),
    );
  }

  Widget _body(List<_SectionSpec> sections) {
    if (_placeLoading) return const Center(child: CircularProgressIndicator());

    final place = _place;
    if (place == null) {
      return ApiErrorView(
        error: _placeError,
        message: "Не удалось открыть место",
        onRetry: _retry,
      );
    }

    return ListView(
      children: [
        _header(place),
        ...sections.expand((section) => [
              Container(key: _anchor(section.title)),
              _Section(title: section.title, children: section.children),
            ]),
        if (_mentionsLoading)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_mentionsError != null)
          // Внутри страницы, а не вместо неё: имена и описание уже загружены, и
          // терять их из-за отказа второго запроса незачем.
          ApiErrorView(
            error: _mentionsError,
            message: "Не удалось загрузить упоминания места",
            onRetry: _retry,
          ),
        _sources(place),
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _header(PlaceDetail place) {
    final about = <String>[
      if (place.kind != null) placeKindLabel(place.kind),
      if (place.status != null) placeStatusLabel(place.status),
      if ((_mentions?.scripture.total ?? 0) > 0)
        "упоминается в Писании: ${_mentions!.scripture.total}",
    ].where((part) => part.isNotEmpty).join("; ");

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            place.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: "OldStandard"),
          ),
          if (about.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(about, style: Theme.of(context).textTheme.bodySmall),
            ),
          if (place.description != null && place.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(place.description!, style: const TextStyle(fontFamily: "OldStandard")),
            ),
          if (place.hasPoint)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: InkWell(
                onTap: () => _openMap(place),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18.0),
                    const SizedBox(width: 6.0),
                    Text(
                      "${place.latitude}, ${place.longitude}",
                      style: TextStyle(color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openMap(PlaceDetail place) async {
    final url = Uri.parse(placeMapUrl(place.latitude!, place.longitude!));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Открыть карту нечем")),
      );
    }
  }

  /// Разделы страницы: только непустые, в порядке страницы сайта.
  List<_SectionSpec> _sections(PlaceDetail place) {
    final mentions = _mentions;
    final sections = <_SectionSpec>[];

    if (mentions != null && mentions.articles.isNotEmpty) {
      sections.add(_SectionSpec("Библейская энциклопедия", [
        for (final article in mentions.articles)
          _Line(
            title: article.name,
            subtitle: "архим. Никифор, 1891",
            onTap: () => Navigator.pushNamed(context, "/reading", arguments: article.address),
          ),
      ]));
    }

    if (place.names.isNotEmpty) {
      sections.add(_SectionSpec("Имена", _names(place)));
    }

    if (place.periods.isNotEmpty) {
      sections.add(_SectionSpec("Эпохи", [
        for (final period in place.periods)
          _Line(title: period.label, subtitle: placeSpanLabel(period.from, period.to)),
      ]));
    }

    if (mentions != null && mentions.relations.isNotEmpty) {
      sections.add(_SectionSpec("Преемственность и отождествления", [
        for (final relation in mentions.relations)
          _Line(
            title: relation.otherName,
            subtitle: [
              placeRelationLabel(relation.type, relation.direction),
              // Надёжность называем только там, где она не само собой:
              // у преемства её не показывают вовсе.
              if (relation.type != "succeeds" && relation.confidence != "certain")
                placeConfidenceLabel(relation.confidence),
            ].where((part) => part.isNotEmpty).join(", "),
            // Сосед без адреса скрыт: имя показываем, вести некуда — его
            // страница ответит «такого места нет».
            onTap: relation.hasPage
                ? () => Navigator.pushNamed(context, "/places", arguments: relation.otherSlug)
                : null,
          ),
      ]));
    }

    if (mentions != null && mentions.scripture.books.isNotEmpty) {
      sections.add(_SectionSpec("В Священном Писании", [
        for (final book in mentions.scripture.books) _book(book),
        if (mentions.scripture.pending > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
            child: Text(
              "Ещё ${mentions.scripture.pending} стихов ждут сверки и здесь не показаны.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ]));
    }

    if (mentions != null && mentions.texts.isNotEmpty) {
      sections.add(_SectionSpec("В чтениях", [
        for (final text in mentions.texts)
          _Line(
            title: text.name,
            subtitle: text.book ?? "",
            onTap: () => Navigator.pushNamed(context, "/reading", arguments: text.address),
          ),
        if (mentions.textsTruncated)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
            child: Text(
              "Показаны первые двести чтений.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ]));
    }

    if (mentions != null && mentions.chants.items.isNotEmpty) {
      sections.add(_SectionSpec("В песнопениях", [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 4.0),
          child: Text(
            mentions.chants.labelled
                ? "Упоминаний: ${mentions.chants.total}; ниже — "
                    "${mentions.chants.shown} разных текстов."
                : "Упоминаний: ${mentions.chants.total}. Певческий корпус сейчас "
                    "недоступен, и чем именно является каждая строка — неизвестно.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        // Без перехода: экрана отдельного песнопения в приложении нет, и
        // подчёркнутая строка обещала бы страницу, которой не существует.
        for (final chant in mentions.chants.items)
          _Line(
            title: chant.context,
            subtitle: [
              if (mentions.chants.labelled && chant.unit != null) chant.unit!,
              if (chant.memory != null) chant.memory!,
            ].join(", "),
          ),
      ]));
    }

    if (mentions != null && mentions.saints.isNotEmpty) {
      sections.add(_SectionSpec("Святые", [
        if (mentions.saintsCaveat.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 6.0),
            child: Text(mentions.saintsCaveat, style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final saint in mentions.saints)
          _Line(
            title: saint.name,
            subtitle: saint.texts > 1 ? "в ${saint.texts} чтениях" : "",
            onTap: () => Navigator.pushNamed(context, "/saints", arguments: saint.dneslovId),
          ),
      ]));
    }

    return sections;
  }

  List<Widget> _names(PlaceDetail place) {
    final widgets = <Widget>[];

    for (final role in roleOrder) {
      final names = place.names.where((name) => name.role == role).toList()
        ..sort((a, b) => (a.from ?? -9999).compareTo(b.from ?? -9999));
      if (names.isEmpty) continue;

      final seen = <String>{};
      final lines = <Widget>[];
      for (final name in names) {
        if (!seen.add("${name.name}|${name.lang}")) continue;
        lines.add(_Line(
          title: name.transliteration == null || name.transliteration!.isEmpty
              ? name.name
              : "${name.name} (${name.transliteration})",
          subtitle: [
            placeLangLabel(name.lang),
            placeSpanLabel(name.from, name.to),
          ].where((part) => part.isNotEmpty).join(", "),
        ));
      }

      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 0.0),
        child: Text(
          placeRoleLabel(role),
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ));

      // Вариантов бывает по два десятка — за шестью прячем, как на сайте:
      // иначе они вытесняют со страницы всё остальное.
      if (role == "variant" && lines.length > 6) {
        widgets.add(ExpansionTile(
          title: Text("${lines.length} прочих написаний"),
          children: lines,
        ));
      } else {
        widgets.addAll(lines);
      }
    }

    return widgets;
  }

  Widget _book(ScriptureBookRef book) {
    final verses = _verses[book.canonId];

    return ExpansionTile(
      title: Text("${book.name} (${book.verses})",
          style: const TextStyle(fontFamily: "OldStandard")),
      onExpansionChanged: (expanded) {
        if (expanded) _openBook(book);
      },
      children: [
        if (_loadingBooks.contains(book.canonId))
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (verses != null)
          for (final verse in verses)
            _Line(
              title: "${verse.abbr ?? book.name} ${verse.chapter}:${verse.verse}",
              subtitle: verse.context,
              onTap: () => _openVerse(verse),
            ),
      ],
    );
  }

  Widget _sources(PlaceDetail place) {
    final external = <Widget>[];
    for (final key in place.externals) {
      final url = placeExternalUrl(key.source, key.id);
      if (url == null) continue;
      external.add(_Line(
        title: placeSourceLabel(key.source),
        subtitle: key.id,
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ));
    }
    for (final link in place.links) {
      if (link.url == null || link.url!.isEmpty) continue;
      external.add(_Line(
        title: link.text ?? link.url!,
        subtitle: "",
        onTap: () => launchUrl(Uri.parse(link.url!), mode: LaunchMode.externalApplication),
      ));
    }

    final attribution = _mentions?.attribution ?? "";

    if (external.isEmpty && attribution.isEmpty) return const SizedBox.shrink();

    return _Section(title: "Источники", children: [
      ...external,
      if (attribution.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
          child: Text(attribution, style: Theme.of(context).textTheme.bodySmall),
        ),
    ]);
  }
}

/// Раздел страницы: имя для оглавления и его содержимое.
class _SectionSpec {
  final String title;
  final List<Widget> children;

  const _SectionSpec(this.title, this.children);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: "OldStandard",
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.title, required this.subtitle, this.onTap});

  final String title;
  final String subtitle;

  /// Есть ли куда вести. Строка без перехода не красится: подчёркнутая строка
  /// обещала бы страницу, которой нет.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: "OldStandard",
            color: onTap == null ? null : Theme.of(context).colorScheme.primary,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}
