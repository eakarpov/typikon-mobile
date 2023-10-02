import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Библиотека"),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
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
                          title: Text(item.name??"test"),
                          subtitle: Text(item.author??"test"),
                          onTap: () => {
                            Navigator.pushNamed(context, "/library", arguments: item.id)
                          },
                        ),
                      );
                    },
                  );
                } else if (future.hasError) {
                  return Text('${future.error}');
                }
                return const CircularProgressIndicator();
              },
            ),
          ),
        ],
      ),
    );
  }
}