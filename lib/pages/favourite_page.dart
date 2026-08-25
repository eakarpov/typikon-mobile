import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:typikon/apiMapper/favourites.dart';
import 'package:typikon/components/api_error_view.dart';
import 'package:typikon/dto/book.dart';
import 'package:typikon/store/actions/actions.dart';
import 'package:typikon/store/favourites_sync.dart';
import 'package:typikon/store/index.dart';

class FavouritePage extends StatefulWidget {
  const FavouritePage(context, {super.key});

  @override
  State<FavouritePage> createState() => _FavouritePageState();
}

class _FavouritePageState extends State<FavouritePage> {
  /// Тексты для показа. Список идентификаторов живёт в сторе, а сами тексты
  /// догружаются пакетным запросом под тот список, который сейчас в сторе.
  Future<BookWithTexts>? _texts;
  List<String> _loadedFor = const [];

  @override
  void initState() {
    super.initState();
    // Заодно досылаем то, что не доехало, и подтягиваем список с сервера:
    // человек мог отмечать тексты и на другом устройстве.
    final store = StoreProvider.of<AppState>(context, listen: false);
    unawaited(syncFavourites(store));
  }

  void _ensureTextsFor(List<String> ids) {
    if (_texts != null && _sameIds(ids, _loadedFor)) return;
    _loadedFor = List<String>.from(ids);
    _texts = ids.isEmpty
        ? Future.value(const BookWithTexts(name: "Избранное", author: "", texts: []))
        : getFavouriteTexts(ids);
  }

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: const Text(
          "Вы ещё ничего не добавили в избранное.\n"
          "Открыв текст, нажмите сердечко в шапке.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _list(List<BookText> texts) {
    return ListView.builder(
      scrollDirection: Axis.vertical,
      itemCount: texts.length,
      itemBuilder: (context, index) {
        final item = texts[index];
        return ListTile(
          leading: const Icon(Icons.favorite, color: Colors.pink, size: 32.0),
          title: Text(item.name, style: const TextStyle(fontFamily: "OldStandard")),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: "Убрать из избранного",
            onPressed: () {
              final store = StoreProvider.of<AppState>(context, listen: false);
              store.dispatch(ToggleFavouriteAction(item.id));
              unawaited(syncFavourites(store));
            },
          ),
          onTap: () => Navigator.pushNamed(context, "/reading", arguments: item.id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Избранное", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: StoreConnector<AppState, List<String>>(
          distinct: true,
          converter: (store) => store.state.favourites.textIds,
          builder: (context, ids) {
            if (ids.isEmpty) return _empty();

            _ensureTextsFor(ids);
            return FutureBuilder<BookWithTexts>(
              future: _texts,
              builder: (context, future) {
                if (future.hasData) {
                  final texts = future.data!.texts;
                  return texts.isEmpty ? _empty() : _list(texts);
                }
                if (future.hasError) {
                  return ApiErrorView(
                    error: future.error,
                    message: "Не удалось загрузить избранное.",
                    onRetry: () => setState(() {
                      _texts = null;
                      _loadedFor = const [];
                    }),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            );
          },
        ),
      ),
    );
  }
}
