import 'package:flutter/material.dart';

import 'package:typikon/components/dossier.dart';
import '../components/saint_icons.dart';
import 'saint_corpus_page.dart';
import '../dto/dneslov/images.dart';
import 'package:typikon/components/reading_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:typikon/apiMapper/saints.dart';
import 'package:typikon/components/api_error_view.dart';
import 'package:typikon/dto/saint.dart';
import 'package:typikon/utils/singing_labels.dart';

/// Страница святого: наша запись и житие из каталога памятей.
///
/// Два источника грузятся врозь и падают врозь. Жития нет у всякой записи, и
/// когда его нет, на экране остаётся всё остальное — имя, дни памяти, службы,
/// тексты. Поэтому и шапка берёт имя из нашей записи, а не из заголовка жития.
class SaintPage extends StatefulWidget {
  final String id;

  const SaintPage(
    BuildContext? context, {
    super.key,
    required this.id,
    this.loadDossier = getSaintDossier,
    this.loadLife = getSaintLife,
    this.loadIcons = getSaintIcons,
  });

  /// Запись каталога. Подменяется тестом, чтобы показать страницу без сети.
  final Future<SaintDossier> Function(String address) loadDossier;

  /// Житие. Подменяется тестом.
  final Future<SaintLife> Function(String address) loadLife;
  final Future<DneslovImageListD> Function(SaintDossier) loadIcons;

  @override
  State<SaintPage> createState() => _SaintPageState();
}

class _SaintPageState extends State<SaintPage> {
  SaintDossier? _dossier;
  Object? _dossierError;
  bool _dossierLoading = true;

  SaintLife? _life;
  Object? _lifeError;
  bool _lifeLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _dossier = null;
    _dossierError = null;
    _dossierLoading = true;
    _life = null;
    _lifeError = null;
    _lifeLoading = true;

    widget
        .loadDossier(widget.id)
        .then((value) {
          if (mounted) {
            setState(() {
              _dossier = value;
              _dossierLoading = false;
            });
          }
        })
        .catchError((Object error) {
          if (mounted) {
            setState(() {
              _dossierError = error;
              _dossierLoading = false;
            });
          }
        });

    // Житие идёт своим запросом и своей веткой состояния. Адрес резолвит
    // сервер — досье дожидаться не нужно.
    widget
        .loadLife(widget.id)
        .then((value) {
          if (mounted) {
            setState(() {
              _life = value;
              _lifeLoading = false;
            });
          }
        })
        .catchError((Object error) {
          if (mounted) {
            setState(() {
              _lifeError = error;
              _lifeLoading = false;
            });
          }
        });
  }

  void _retry() => setState(_load);

  void _openLinks(List<SaintLifeLink> links) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(5.0, 10.0, 5.0, 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: links
              .map(
                (link) => Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: InkWell(
                    onTap: () => launchUrl(
                      Uri.parse(link.url),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(
                      link.url,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String get _title {
    final name = _dossier?.name;
    if (name != null && name.isNotEmpty) return name;
    // Досье ещё не пришло или не пришло вовсе — заголовок жития лучше пустоты.
    final memo = _life?.memo?.title ?? "";
    if (memo.isNotEmpty) return memo;
    return _dossierError != null ? "Ошибка загрузки" : "";
  }

  @override
  Widget build(BuildContext context) {
    final life = _life;
    final links = life?.links ?? const <SaintLifeLink>[];

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _title,
            style: const TextStyle(fontFamily: "OldStandard"),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: <Widget>[
            if (links.isNotEmpty)
              IconButton(
                tooltip: "Ссылки",
                onPressed: () => _openLinks(links),
                icon: const Icon(Icons.link, color: Colors.white),
              ),
            if (life != null)
              IconButton(
                onPressed: () => launchUrl(
                  Uri.parse("https://dneslov.org/${life.slug}?c=днес,рпц"),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.outbond_outlined, color: Colors.white),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Житие"),
              Tab(text: "Память"),
              Tab(text: "Тексты"),
              Tab(text: "Иконы"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _lifeTab(),
            _dossierTab(_memoryTab),
            _dossierTab(_textsTab),
            _dossierTab(
              (saint) => SaintIcons(saint: saint, loader: widget.loadIcons),
            ),
          ],
        ),
      ),
    );
  }

  // --- Житие --------------------------------------------------------------

  Widget _lifeTab() {
    if (_lifeLoading) return const Center(child: CircularProgressIndicator());

    if (_lifeError != null) {
      // errorViewFor различает честный отказ («житие не связано с каталогом» —
      // кнопки «Повторить» нет, говорит сам сервер) и обрыв сети.
      return errorViewFor(
        context,
        _lifeError,
        "Не удалось загрузить житие.",
        _retry,
      );
    }

    final life = _life!;
    if (!life.hasText) {
      return const _Quiet("В Днеслове нет текста жития для этой записи.");
    }

    // Настройки чтения, а не только шрифт: размер, цвет и интервал житие
    // брало системные, хотя это такой же текст для чтения, как прочие.
    return ReadingMarkdown(life.memo!.description);
  }

  // --- Наша запись --------------------------------------------------------

  Widget _dossierTab(Widget Function(SaintDossier) build) {
    if (_dossierLoading)
      return const Center(child: CircularProgressIndicator());

    if (_dossierError != null) {
      return ApiErrorView(
        error: _dossierError,
        message: "Не удалось загрузить сведения о святом.",
        onRetry: _retry,
      );
    }

    return build(_dossier!);
  }

  Widget _memoryTab(SaintDossier saint) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        _head(saint),
        if (saint.memoryDates.isNotEmpty)
          DossierSection(
            title: "Дни памяти",
            children: saint.memoryDates
                .map(
                  (date) => DossierLine(
                    title: date.civil,
                    subtitle: [
                      date.julian,
                      if ((date.note ?? "").isNotEmpty) date.note!,
                    ].join(" — "),
                  ),
                )
                .toList(),
          ),
        if (saint.memories.isNotEmpty)
          DossierSection(
            // Не «дни памяти»: здесь служба, напечатанная в книге, а не число
            // в календаре, и знак службы — как раз то, чем она отличается от
            // прочих памятей того же дня.
            title: "Памяти в книгах",
            children: saint.memories.map((memory) {
              final sign = serviceSignLabel(memory.sign);
              return DossierLine(
                title: memory.label,
                subtitle: [
                  if ((memory.address ?? "").isNotEmpty) memory.address!,
                  if (sign.isNotEmpty) sign,
                ].join(", "),
              );
            }).toList(),
          ),
        if (saint.dedications.isNotEmpty)
          DossierSection(
            title: "Храмы",
            children: saint.dedications
                .map(
                  (dedication) => DossierLine(
                    title: dedication.name,
                    subtitle: _temples(dedication.count),
                  ),
                )
                .toList(),
          ),
        if (saint.noble != null)
          DossierSection(
            title: "Родословная",
            children: [
              DossierLine(
                title: saint.noble!.name ?? "Есть запись в родословной",
                subtitle: "",
              ),
            ],
          ),
        if ((saint.caveat ?? "").isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
            child: Text(
              saint.caveat!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _head(SaintDossier saint) {
    final about = <String>[
      ...saint.orders.map((order) => order.label),
      if ((saint.kindLabel ?? "").isNotEmpty) saint.kindLabel!,
      if ((saint.baseYearLabel ?? "").isNotEmpty) saint.baseYearLabel!,
    ];

    final roundel = saint.roundelUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (roundel != null && roundel.isNotEmpty) ...[
            ClipOval(
              child: Image.network(
                roundel,
                width: 56.0,
                height: 56.0,
                fit: BoxFit.cover,
                // Образ с чужого сайта: не загрузился — просто нет образа.
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 12.0),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saint.name,
                  style: const TextStyle(
                    fontFamily: "OldStandard",
                    fontSize: 18.0,
                  ),
                ),
                if (about.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      about.join(", "),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (saint.altNames.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      saint.altNames.join(", "),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: "OldStandard",
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textsTab(SaintDossier saint) {
    final works = <SaintWork>[
      ...?saint.works,
      for (final a in saint.akathists ?? const <SaintAkathist>[])
        if ((a.id ?? '').isNotEmpty)
          SaintWork(
            id: a.id!,
            genre: 'akathist',
            reader: 'akathist',
            title: a.title ?? a.memory ?? 'Акафист',
            subtitle: a.stanzas == null ? null : 'Строф: ${a.stanzas}',
          ),
    ];
    const genres = {
      'reading': 'Четьи тексты',
      'troparion': 'Тропари',
      'kontakion': 'Кондаки',
      'magnification': 'Величания',
      'canon': 'Каноны',
      'akathist': 'Акафисты',
      'service': 'Службы',
      'other': 'Другие тексты',
    };
    final groups = <String, List<Widget>>{};
    for (final t in saint.texts) {
      (groups[t.genre] ??= []).add(_text(t));
    }
    final seen = <String>{};
    for (final w in works) {
      if (w.id.isEmpty || !seen.add('${w.reader}|${w.id}|${w.language}')) {
        continue;
      }
      final genre = genres.containsKey(w.genre) ? w.genre : 'other';
      (groups[genre] ??= []).add(_work(w));
    }
    final unavailable = saint.works == null && saint.akathistsUnknown;
    if (groups.isEmpty && saint.mentions.isEmpty && !unavailable) {
      return const _Quiet('Связанных текстов для этой записи пока нет.');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (unavailable)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Певческий корпус временно недоступен.'),
          ),
        for (final genre in genres.entries)
          if ((groups[genre.key] ?? []).isNotEmpty)
            DossierSection(title: genre.value, children: groups[genre.key]!),
        if (saint.mentions.isNotEmpty)
          DossierSection(
            title: 'Упоминания',
            children: saint.mentions.map(_text).toList(),
          ),
      ],
    );
  }

  Widget _work(SaintWork work) {
    final route = switch (work.reader) {
      'canon' => '/canons',
      'akathist' => '/akathists',
      'chant' || 'service' => '/saint-text',
      _ => null,
    };
    return ListTile(
      title: Text(
        work.title,
        style: const TextStyle(fontFamily: 'OldStandard'),
      ),
      subtitle: work.subtitle == null
          ? null
          : Text(
              [
                work.subtitle!,
                if (work.language != null) languageLabel(work.language),
              ].join(' · '),
            ),
      trailing: route == null ? null : const Icon(Icons.chevron_right),
      onTap: route == null
          ? null
          : () => Navigator.pushNamed(
              context,
              route,
              arguments: route == '/saint-text'
                  ? SaintCorpusTarget(
                      reader: work.reader,
                      id: work.id,
                      title: work.title,
                      language: work.language,
                    )
                  : work.id,
            ),
    );
  }

  Widget _text(SaintText text) {
    final about = text.author ?? text.description ?? "";
    return ListTile(
      title: Text(text.name, style: const TextStyle(fontFamily: "OldStandard")),
      subtitle: about.isEmpty
          ? null
          : Text(about, style: Theme.of(context).textTheme.bodySmall),
      // И служба, и упоминание — тексты корпуса, и открываются оба как тексты.
      onTap: () => Navigator.pushNamed(context, "/reading", arguments: text.id),
    );
  }
}

String _temples(int count) {
  if (count <= 0) return "";
  final hundred = count % 100;
  final ten = count % 10;
  if (hundred >= 11 && hundred <= 14) return "$count храмов";
  if (ten == 1) return "$count храм";
  if (ten >= 2 && ten <= 4) return "$count храма";
  return "$count храмов";
}

/// Пустой раздел словами. Пустой экран читатель прочтёт как незагрузившийся.
class _Quiet extends StatelessWidget {
  const _Quiet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
