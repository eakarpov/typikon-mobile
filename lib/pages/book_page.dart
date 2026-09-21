import 'package:flutter/material.dart';

import 'package:typikon/components/async_view.dart';
import 'package:typikon/apiMapper/library.dart';
import 'package:typikon/dto/book.dart';
import 'package:typikon/components/dneslov/roundels.dart';

class BookPage extends StatefulWidget {
  final String id;

  const BookPage(context, {super.key, required this.id});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  late Future<BookWithTexts> book;

  @override
  void initState() {
    super.initState();
    book = getBook(widget.id);
  }

  /// Повторная попытка после отказа. Прежде на её месте стоял текст
  /// исключения: прочесть его нечем, а повторить — нечем тем более.
  Future<void> _refresh() {
    _retry();
    return settle(book);
  }

  void _retry() {
    setState(() {
      book = getBook(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<BookWithTexts>(
          future: book,
          builder: (context, future) {
            if (future.hasData) {
              String name = future.data!.name;
              return Text(name);
            } else if (future.hasError) {
              // В заголовке — короткий ярлык, а не вид ошибки: целый экран
              // с «Повторить» показывается ниже, в теле страницы.
              return const Text("Книга", style: TextStyle(fontFamily: "OldStandard"));
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AsyncView<BookWithTexts>(
          future: book,
          message: "Не удалось загрузить книгу.",
          onRetry: _retry,
          onRefresh: _refresh,
          isEmpty: (data) => data.texts.isEmpty,
          emptyMessage: "В этой книге пока нет текстов.",
          builder: (context, data) => ListView.builder(
            itemCount: data.texts.length,
            itemBuilder: (context, index) => Roundels(context, item: data.texts[index]),
          ),
        ),
      ),
    );
  }
}