import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:typikon/dto/book.dart';
import 'package:typikon/dto/text.dart';
import '../apiMapper/reading.dart';

class TextPage extends StatefulWidget {
  final String id;

  const TextPage(context, {super.key, required this.id});

  @override
  State<TextPage> createState() => _TextPageState();
}

class _TextPageState extends State<TextPage> {
  late Future<Reading> reading;

  @override
  void initState() {
    super.initState();
    reading = getText(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Reading>(
          future: reading,
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
      body: Column(
        children: <Widget>[
          Expanded(
            child: FutureBuilder<Reading>(
              future: reading,
              builder: (context, future) {
                if (future.hasData) {
                  String content = future.data!.content;
                  String name = future.data!.name;
                  return Column(
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(content),
                    ],
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