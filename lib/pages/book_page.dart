import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:typikon/apiMapper/library.dart';
import 'package:typikon/dto/book.dart';
import 'package:typikon/dto/library.dart';
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
              return Text('${future.error}');
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
      body: Container(
        color: const Color(0xffffffff),
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
              return Text('${future.error}');
            }
            return Container(
              color: const Color(0xffffffff),
              width: double.infinity,
              height: double.infinity,
              child: Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}