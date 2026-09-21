import 'package:flutter/material.dart';

import 'package:typikon/components/api_error_view.dart';
import 'package:intl/intl.dart';
import 'package:typikon/apiMapper/library.dart';
import 'package:typikon/dto/library.dart';

import '../apiMapper/calendar.dart';
import '../dto/calendar.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Библиотека", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<BookList>(
          future: bookList,
          builder: (context, future) {
            if (future.hasData) {
              List<Book> list = future.data!.list;
              return ListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Container(
                    child: ListTile(
                      title: Text(item.name ?? "Без названия"),
                      // Автора может не быть вовсе — тогда строки под названием нет.
                      subtitle: (item.author ?? "").isEmpty ? null : Text(item.author!),
                      onTap: () => {
                        Navigator.pushNamed(context, "/library", arguments: item.id)
                      },
                    ),
                  );
                },
              );
            } else if (future.hasError) {
              return ApiErrorView(
                error: future.error,
                message: "Не удалось загрузить библиотеку.",
                onRetry: _retry,
              );
            }
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }
}