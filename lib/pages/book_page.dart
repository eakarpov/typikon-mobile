import 'package:flutter/material.dart';

import 'package:typikon/components/api_error_view.dart';
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
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<BookWithTexts>(
          future: book,
          builder: (context, future) {
            if (future.hasData) {
              List<BookText> list = future.data!.texts;
              return ListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Roundels(
                    context,
                    item: item,
                  );
                },
              );
            } else if (future.hasError) {
              return ApiErrorView(
                error: future.error,
                message: "Не удалось загрузить книгу.",
                onRetry: _retry,
              );
            }
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: double.infinity,
              height: double.infinity,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }
}