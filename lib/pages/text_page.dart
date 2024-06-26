import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:redux/redux.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:typikon/store/models/models.dart';
import 'package:typikon/dto/book.dart';
import 'package:typikon/dto/text.dart';
import 'package:typikon/dto/dneslov/images.dart';
import '../apiMapper/reading.dart';
import "../apiMapper/dneslov/images.dart";

class TextPage extends StatefulWidget {
  final String id;

  const TextPage(context, {super.key, required this.id});

  @override
  State<TextPage> createState() => _TextPageState();
}

class _TextPageState extends State<TextPage> {
  late Future<Reading> reading;
  late Future<DneslovImageListD> dneslovImages;

  @override
  void initState() {
    super.initState();
    reading = getText(widget.id);
    reading.then((value) => {
      if (value!.dneslovId != null) {
        dneslovImages = fetchDneslovImagesD(value!.dneslovId!)
      }
    });
  }

  void onClick(String link) {
    Uri myUrl = Uri.parse(link);
    launchUrl(myUrl);
  }

  Widget imageCard(value) {
    print(value);
    return Image(
      image: NetworkImage(value),
    );
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
      body: Container(
        color: const Color(0xffffffff),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
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
                      Row(
                        children: [
                          if (future.data!.ruLink != null) TextButton(
                              onPressed: () => onClick(future.data!.ruLink as String),
                              child: Text("Русский текст")
                          ),
                          if (future.data!.link != null) TextButton(
                              onPressed: () => onClick(future.data!.link as String),
                              child: Text("Оригинальный текст")
                          ),
                        ],
                      ),
                      Text(content,
                          textAlign: TextAlign.justify,
                          style: TextStyle(fontFamily: "OldStandard", fontSize: StoreProvider.of<AppState>(context).state.settings.fontSize.toDouble())
                      ),
                      if (future.data!.dneslovId != null) FutureBuilder<DneslovImageListD>(
                          future: dneslovImages,
                          builder: (context, future) {
                            if (future.hasData) {
                              print(future.data!.list.map((item) => item.url));
                              return CarouselSlider(
                                options: CarouselOptions(height: 400.0),
                                items: future.data!.list.map((item) {
                                  return Builder(
                                    builder: (BuildContext context) {
                                      return Container(
                                          width: MediaQuery.of(context).size.width,
                                          margin: EdgeInsets.symmetric(horizontal: 5.0),
                                          decoration: BoxDecoration(
                                          ),
                                          child: Image(
                                            image: NetworkImage(item.thumb_url),
                                          ),
                                      );
                                    },
                                  );
                                }).toList(),
                              );
                              // return Column(
                              //   children: future.data!.list.map((item) => imageCard(item.url)).toList(),
                              // );
                            }
                            return Text("");
                          }
                      ),
                    ],
                  ),
                ),
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