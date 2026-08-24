import 'dart:async';

import 'package:flutter/material.dart';

import 'package:typikon/api/search.dart';
import 'package:typikon/components/api_error_view.dart';
import 'package:typikon/dto/search.dart';
import "package:typikon/apiMapper/search.dart";

class SearchPage extends StatefulWidget {
  const SearchPage(context, {super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();

  /// null — ещё ничего не искали, показываем подсказку, а не пустую выдачу.
  Future<List<SearchBookText>>? _results;

  String _query = "";
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Запрос уходит сам, через паузу после набора: кнопка "ОК" заставляла
  /// подтверждать каждый поиск, а слать запрос на каждую букву нельзя — ручка
  /// тяжёлая и ограничена по частоте.
  void _onQueryChanged(String value) {
    // setState нужен и до самого поиска: от пустоты строки зависит крестик
    // очистки в поле ввода.
    setState(() {
      _query = value;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _runSearch);
  }

  void _runSearch() {
    _debounce?.cancel();
    final query = _query.trim();
    setState(() {
      _results = query.isEmpty ? null : getSearchResult(query);
    });
  }

  Widget _hint(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _resultTile(SearchBookText item) {
    final excerpt = item.excerpt;
    return ListTile(
      title: Text(
        item.name,
        style: const TextStyle(fontFamily: "OldStandard", fontWeight: FontWeight.bold),
      ),
      subtitle: (item.author == null && excerpt == null)
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.author != null)
                  Text(
                    item.author!,
                    style: TextStyle(
                      fontFamily: "OldStandard",
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                if (excerpt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      excerpt,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: "OldStandard"),
                    ),
                  ),
              ],
            ),
      isThreeLine: excerpt != null,
      onTap: () => Navigator.pushNamed(context, "/reading", arguments: item.id),
    );
  }

  Widget _buildResults() {
    if (_results == null) {
      return _hint(
        "Поиск идёт по названиям и по самим текстам — можно искать слово или строку из чтения.",
      );
    }

    return FutureBuilder<List<SearchBookText>>(
      future: _results,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.error is SearchQueryTooShortException) {
          return _hint("Введите хотя бы $minSearchQueryLength символа.");
        }
        if (snapshot.hasError) {
          return ApiErrorView(
            error: snapshot.error,
            message: "Не удалось выполнить поиск.",
            onRetry: _runSearch,
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _hint("Ничего не нашлось. Попробуйте другое слово или его часть.");
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, index) => _resultTile(items[index]),
          separatorBuilder: (context, index) => const Divider(height: 1),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Поиск по текстам", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 0),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                labelText: 'Поиск',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: "Очистить",
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged("");
                          _runSearch();
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }
}
