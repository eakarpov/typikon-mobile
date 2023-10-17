import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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

  void onClickRu(String link) {
    Uri myUrl = Uri.parse(link);
    launchUrl(myUrl);
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
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 12.0),
                              child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                            ),
                            if (future.data!.ruLink != null) TextButton(
                              onPressed: () => onClickRu(future.data!.ruLink as String),
                              child: Text("Русский текст")
                            ),
                            Text(content),
                          ],
                        ),
                      ),
                    );
                  } else if (future.hasError) {
                    return Text('${future.error}');
                  }
                  return Container(
                    color: const Color(0xffCCCCCC),
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
          ],
      ),
    );
  }
}