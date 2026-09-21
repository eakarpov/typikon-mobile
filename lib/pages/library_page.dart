import 'package:flutter/material.dart';

import 'package:typikon/components/async_view.dart';
import 'package:typikon/apiMapper/library.dart';
import 'package:typikon/dto/library.dart';


class LibraryPage extends StatefulWidget {
  const LibraryPage(context, {super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late Future<BookList> bookList;

  @override
  void initState() {
    super.initState();
    bookList = getBooks();
  }

  /// Повторная попытка после отказа. Прежде на её месте стоял текст
  /// исключения: прочесть его нечем, а повторить — нечем тем более.
  void _retry() {
    setState(() {
      bookList = getBooks();
    });
  }

  /// То же, что «Повторить», но жестом — и дождавшись ответа, иначе кольцо
  /// обновления пропадёт раньше, чем придут книги.
  Future<void> _refresh() {
    _retry();
    return settle(bookList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Библиотека", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AsyncView<BookList>(
          future: bookList,
          message: "Не удалось загрузить библиотеку.",
          onRetry: _retry,
          onRefresh: _refresh,
          isEmpty: (data) => data.list.isEmpty,
          emptyMessage: "В библиотеке пока нет книг.",
          builder: (context, data) => ListView.builder(
            itemCount: data.list.length,
            itemBuilder: (context, index) {
              final item = data.list[index];
              return ListTile(
                title: Text(item.name ?? "Без названия"),
                // Автора может не быть вовсе — тогда строки под названием нет.
                subtitle: (item.author ?? "").isEmpty ? null : Text(item.author!),
                onTap: () =>
                    Navigator.pushNamed(context, "/library", arguments: item.id),
              );
            },
          ),
        ),
      ),
    );
  }
}
