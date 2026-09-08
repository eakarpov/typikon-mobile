import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:typikon/apiMapper/saints.dart';
import 'package:typikon/components/api_error_view.dart';
import 'package:typikon/dto/saint.dart';
import 'package:typikon/utils/singing_labels.dart';

/// Страница святого: наша запись и житие со стороннего сайта.
///
/// Два источника грузятся врозь и падают врозь. Житие приходит с dneslov.org,
/// который молчит заметно чаще нас, и когда он молчит, на экране остаётся всё
/// остальное — имя, дни памяти, службы, тексты. Поэтому и шапка берёт имя из
/// нашей записи, а не из заголовка жития.
class SaintPage extends StatefulWidget {
  final String id;

  const SaintPage(context, {super.key, required this.id});

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

    final dossier = getSaintDossier(widget.id);

    dossier.then((value) {
      if (mounted) setState(() { _dossier = value; _dossierLoading = false; });
    }).catchError((Object error) {
      if (mounted) setState(() { _dossierError = error; _dossierLoading = false; });
    });

    // Житие идёт своим запросом и своей веткой состояния. Досье оно дожидается
    // только за номером святцев, и только когда адрес — наш слуг: dneslov на
    // чужой слуг не отвечает вовсе (см. getSaintLife).
    getSaintLife(widget.id, dossier: dossier).then((value) {
      if (mounted) setState(() { _life = value; _lifeLoading = false; });
    }).catchError((Object error) {
      if (mounted) setState(() { _lifeError = error; _lifeLoading = false; });
    });
  }

  void _retry() => setState(_load);

  void _openLinks(List<DneslovLink> links) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(5.0, 10.0, 5.0, 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: links
              .map((link) => Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: InkWell(
                      onTap: () => launchUrl(
                        Uri.parse(link.url),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(link.url, style: const TextStyle(color: Colors.blue)),
                    ),
                  ))
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
    final links = life?.links ?? const <DneslovLink>[];

    return DefaultTabController(
      length: 3,
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
            ],
          ),
        ),
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBarView(
            children: [
              _lifeTab(),
              _dossierTab(_memoryTab),
              _dossierTab(_textsTab),
            ],
          ),
        ),
      ),
    );
  }

  // --- Житие --------------------------------------------------------------

  Widget _lifeTab() {
    if (_lifeLoading) return const Center(child: CircularProgressIndicator());

    if (_lifeError != null) {
      return ApiErrorView(
        error: _lifeError,
        message: "Не удалось загрузить житие.",
        hint: "Жития приходят со стороннего сайта dneslov.org — иногда он недоступен.",
        onRetry: _retry,
      );
    }

    final life = _life!;
    if (!life.hasText) {
      return const _Quiet("Жития у этой памяти на dneslov.org нет.");
    }

    // Шрифт чтений, а не системный: до сих пор житие было единственным местом
    // на странице, набранным чужим.
    final theme = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return Markdown(
      data: life.memo!.description,
      styleSheet: theme.copyWith(
        p: theme.p?.copyWith(fontFamily: "OldStandard"),
        h1: theme.h1?.copyWith(fontFamily: "OldStandard"),
        h2: theme.h2?.copyWith(fontFamily: "OldStandard"),
        h3: theme.h3?.copyWith(fontFamily: "OldStandard"),
        listBullet: theme.listBullet?.copyWith(fontFamily: "OldStandard"),
        blockquote: theme.blockquote?.copyWith(fontFamily: "OldStandard"),
      ),
    );
  }

  // --- Наша запись --------------------------------------------------------

  Widget _dossierTab(Widget Function(SaintDossier) build) {
    if (_dossierLoading) return const Center(child: CircularProgressIndicator());

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
    final akathists = saint.akathists;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        _head(saint),
        if (saint.memoryDates.isNotEmpty)
          _Section(
            title: "Дни памяти",
            children: saint.memoryDates
                .map((date) => _Line(
                      title: date.civil,
                      subtitle: [
                        date.julian,
                        if ((date.note ?? "").isNotEmpty) date.note!,
                      ].join(" — "),
                    ))
                .toList(),
          ),
        if (saint.memories.isNotEmpty)
          _Section(
            // Не «дни памяти»: здесь служба, напечатанная в книге, а не число
            // в календаре, и знак службы — как раз то, чем она отличается от
            // прочих памятей того же дня.
            title: "Памяти в книгах",
            children: saint.memories.map((memory) {
              final sign = serviceSignLabel(memory.sign);
              return _Line(
                title: memory.label,
                subtitle: [
                  if ((memory.address ?? "").isNotEmpty) memory.address!,
                  if (sign.isNotEmpty) sign,
                ].join(", "),
              );
            }).toList(),
          ),
        if (akathists != null && akathists.isNotEmpty)
          _Section(
            title: "Акафисты",
            children: akathists
                .map((akathist) => _Line(
                      title: akathist.title ?? akathist.memory ?? "Акафист",
                      subtitle: akathist.stanzas == null ? "" : "икосов и кондаков: ${akathist.stanzas}",
                      // Вероятнее всего, это и будет главным входом в раздел:
                      // акафист ищут по святому, а не по перечню из тысячи.
                      onTap: (akathist.id ?? "").isEmpty
                          ? null
                          : () => Navigator.pushNamed(context, "/akathists",
                              arguments: akathist.id),
                    ))
                .toList(),
          ),
        if (saint.dedications.isNotEmpty)
          _Section(
            title: "Храмы",
            children: saint.dedications
                .map((dedication) => _Line(
                      title: dedication.name,
                      subtitle: _temples(dedication.count),
                    ))
                .toList(),
          ),
        if (saint.noble != null)
          _Section(
            title: "Родословная",
            children: [_Line(title: saint.noble!.name ?? "Есть запись в родословной", subtitle: "")],
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
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
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
                  style: const TextStyle(fontFamily: "OldStandard", fontSize: 18.0),
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
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontFamily: "OldStandard"),
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
    if (saint.texts.isEmpty && saint.mentions.isEmpty) {
      return const _Quiet("Текстов этому святому в корпусе пока нет.");
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        if (saint.texts.isNotEmpty)
          _Section(title: "Служба", children: saint.texts.map(_text).toList()),
        if (saint.mentions.isNotEmpty)
          _Section(title: "Упоминания", children: saint.mentions.map(_text).toList()),
      ],
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

  /// Есть ли куда вести. Строки досье по большей части никуда не ведут —
  /// подчёркнутая строка без перехода обещала бы страницу, которой нет.
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
