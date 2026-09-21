import 'package:flutter/material.dart';

import '../apiMapper/singing.dart';
import '../apiMapper/v2/errors.dart';
import '../dto/paged.dart';
import 'api_error_view.dart';

/// Список, догружающий себя по прокрутке.
///
/// Механика перенесена со страницы знаков (`signs_page.dart`), где она сложилась
/// первой: порог в 400 точек до конца, один флаг занятости вместо очереди, и
/// подвал третьим состоянием — ошибка, крутилка или ничего. Вынесена сюда,
/// потому что вкладок поиска стало две, и переписывать её в каждой значило бы
/// трижды ошибиться на границе последней страницы.
///
/// [resetToken] — то, от чего зависит выдача (для поиска это строка запроса).
/// Сменился — список начинается заново. Сравнивать сами замыкания нельзя: у них
/// новая тождественность на каждой перерисовке.
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.resetToken,
    required this.load,
    required this.itemBuilder,
    required this.emptyMessage,
    this.errorMessage = "Не удалось выполнить поиск.",
    this.separated = true,
  });

  final Object resetToken;
  final Future<Paged<T>> Function(int offset) load;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;
  final String errorMessage;
  final bool separated;

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  final ScrollController _scrollController = ScrollController();
  final List<T> _items = [];

  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _loadedOnce = false;
  Object? _error;

  /// Номер нынешней выдачи. Растёт при каждой смене запроса; ответ, ушедший при
  /// прежнем номере, молча отбрасывается.
  ///
  /// Одного флага занятости тут мало, и стоило это зависшей крутилки: сменился
  /// запрос, пока прежний был в пути, — новая загрузка не начиналась («занято»),
  /// а прежний ответ выходил по несовпадению запроса, флага не сняв. Список
  /// оставался крутиться, пока с экрана не уйдёшь.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void didUpdateWidget(covariant PagedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) _restart();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _restart() {
    _generation++;
    setState(() {
      // Прежний запрос ещё в пути, но он уже не наш: его ответ будет отброшен,
      // и ждать его новой выдаче незачем.
      _isLoading = false;
      _items.clear();
      _offset = 0;
      _hasMore = true;
      _loadedOnce = false;
      _error = null;
    });
    _loadNextPage();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;
    final generation = _generation;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await widget.load(_offset);
      // Пока ходили в сеть, запрос мог смениться: ответ на прежний вопрос в
      // новом списке выглядел бы как найденное не то.
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _offset += page.items.length;
        _hasMore = page.hasMore;
        _isLoading = false;
        _loadedOnce = true;
      });
      _fillViewport();
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _isLoading = false;
        _loadedOnce = true;
      });
    }
  }

  /// Страница короче экрана — прокручивать нечего, и догрузка по прокрутке не
  /// началась бы никогда (планшет, короткие строки). Добираем, пока экран не
  /// заполнится или выдача не кончится.
  void _fillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) _loadNextPage();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_error != null) return searchErrorView(context, _error!, widget.errorMessage, _loadNextPage);
      if (_isLoading || !_loadedOnce) return const Center(child: CircularProgressIndicator());
      return searchHint(widget.emptyMessage);
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: _items.length + 1,
      separatorBuilder: (context, index) =>
          widget.separated ? const Divider(height: 1) : const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index == _items.length) return _footer(context);
        return widget.itemBuilder(context, _items[index]);
      },
    );
  }

  Widget _footer(BuildContext context) {
    if (_error != null) {
      return searchErrorView(context, _error!, widget.errorMessage, _loadNextPage);
    }
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Короткая подсказка вместо списка — «ещё не искали», «ничего не нашлось».
Widget searchHint(String message) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );

/// Отказ поиска, названный своим именем.
///
/// Четыре случая, и каждый читателю говорит разное: слишком короткий запрос —
/// его дело поправимо; корпус не выложен — не его вина и повторять бесполезно;
/// раздел не дан по ключу — тем более; слишком часто — надо подождать. Общее
/// «не удалось выполнить поиск» на всех четырёх было бы неправдой в трёх, и в
/// трёх же предлагало бы кнопку «Повторить» там, где повтор не поможет.
Widget searchErrorView(
  BuildContext context,
  Object error,
  String fallbackMessage,
  VoidCallback onRetry,
) {
  if (error is SearchQueryTooShort) {
    return searchHint("Введите хотя бы ${error.minLength} символа.");
  }

  if (error is CorpusUnavailableException) {
    return ApiErrorView(
      error: error,
      message: error.message,
      hint: "Это не поломка приложения: корпус певческих текстов выкладывается "
          "на сервер отдельно, и сейчас его там нет. Повторять бесполезно.",
    );
  }

  if (error is ApiUnauthorizedException) {
    // Повторять нечего: раздел не дают, а не он сломался.
    return ApiErrorView(error: error, message: error.message);
  }

  if (error is ApiRateLimitedException) {
    return ApiErrorView(error: error, message: error.message, hint: error.hint, onRetry: onRetry);
  }

  return ApiErrorView(error: error, message: fallbackMessage, onRetry: onRetry);
}
