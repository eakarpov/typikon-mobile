import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:typikon/apiMapper/signs.dart';
import 'package:typikon/components/api_error_view.dart';
import 'package:typikon/dto/signs.dart';
import 'package:typikon/utils/reading_style.dart';
import 'package:typikon/utils/signs.dart';

/// Заголовок раздела — именительный ("Сентябрь"), дата памяти — родительный
/// ("1 сентября"), поэтому списка два, а не один.
const List<String> _monthsNominative = [
  "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
  "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь",
];

const List<String> _monthsGenitive = [
  "января", "февраля", "марта", "апреля", "мая", "июня",
  "июля", "августа", "сентября", "октября", "ноября", "декабря",
];

bool _isMonth(int? month) => month != null && month >= 1 && month <= 12;

String _monthTitle(int? month) => _isMonth(month) ? _monthsNominative[month! - 1] : "Без даты";

String _dateTitle(Sign item) {
  if (item.date == null || !_isMonth(item.month)) return "";
  return "${item.date} ${_monthsGenitive[item.month! - 1]}";
}

class SignsPage extends StatefulWidget {
  const SignsPage(context, {super.key});

  @override
  State<SignsPage> createState() => _SignsPageState();
}

class _SignsPageState extends State<SignsPage> {
  final ScrollController _scrollController = ScrollController();
  final List<Sign> _items = [];

  int _loadedPages = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) _loadNextPage();
  }

  /// Список приходит страницами по два десятка на четыре с половиной сотни
  /// памятей, поэтому догружаем по мере прокрутки, а не одним запросом.
  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await getSigns(page: _loadedPages + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.list);
        _loadedPages += 1;
        _total = page.total;
        // Пустая страница — тоже конец: иначе на рассинхроне total и выдачи
        // догрузка крутилась бы вечно.
        _hasMore = page.list.isNotEmpty && page.hasMore;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  void _retry() {
    setState(() => _error = null);
    _loadNextPage();
  }

  Future<void> _openSource(Sign item) async {
    final url = item.sourceUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _tile(BuildContext context, Sign item, {required bool showMonth}) {
    final glyph = item.sign == null ? null : signGlyph(item.sign!);
    final textColor = readingTextColor(context);
    final subtitle = [
      if (item.sign != null) signLabel(item.sign!),
      if (item.signConditional) "знак с оговоркой",
    ].join(" · ");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMonth) Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
          child: Text(
            _monthTitle(item.month),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ),
        ListTile(
          leading: glyph == null
              ? const SizedBox(width: 24)
              : Text(
                  glyph.glyph,
                  style: TextStyle(fontSize: 20, color: glyph.color ?? textColor),
                ),
          title: Text(
            item.name ?? "Без названия",
            style: TextStyle(fontFamily: "OldStandard", color: textColor),
          ),
          subtitle: Text(
            [_dateTitle(item), subtitle].where((s) => s.isNotEmpty).join(" — "),
            style: const TextStyle(fontFamily: "OldStandard", color: Colors.grey),
          ),
          trailing: item.sourceUrl == null || item.sourceUrl!.isEmpty
              ? null
              : const Icon(Icons.open_in_new, size: 18),
          // Своей страницы у памяти нет — прежний переход вёл на несуществующий
          // маршрут "/sign". Ведём в источник, где знак и прописан.
          onTap: item.sourceUrl == null || item.sourceUrl!.isEmpty ? null : () => _openSource(item),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: ApiErrorView(
          error: _error,
          message: "Не удалось загрузить список памятей.",
          offlineMessage: "Нет соединения с интернетом. Список памятей ещё не загружался, поэтому офлайн он недоступен.",
          onRetry: _retry,
        ),
      );
    }
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _total > 0 ? "Список памятей ($_total)" : "Список памятей",
          style: TextStyle(fontFamily: "OldStandard"),
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: _items.isEmpty
            ? _footer(context)
            : ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.vertical,
                itemCount: _items.length + 1,
                itemBuilder: (context, index) {
                  if (index == _items.length) return _footer(context);
                  final item = _items[index];
                  final previous = index == 0 ? null : _items[index - 1];
                  return _tile(
                    context,
                    item,
                    showMonth: previous == null || previous.month != item.month,
                  );
                },
              ),
      ),
    );
  }
}
