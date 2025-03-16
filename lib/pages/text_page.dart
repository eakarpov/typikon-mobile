import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:redux/redux.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import "package:typikon/components/fusion_text.dart";
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

  bool isFavourite = false;

  @override
  void initState() {
    super.initState();
    reading = getText(widget.id);
    reading.then((value) => {
      if (value!.dneslovId != null) {
        dneslovImages = fetchDneslovImagesD(value!.dneslovId!)
      }
    });
    SharedPreferences.getInstance().then((prefs){
      List<String>? liked = prefs.getStringList("favourites") ?? [];
      if (liked.contains(widget.id)) {
        setState(() {
          isFavourite = true;
        });
      }
    });
  }

  void onClick(String link) {
    Uri myUrl = Uri.parse(link);
    launchUrl(myUrl);
  }

  Widget imageCard(value) {
    return Image(
      image: NetworkImage(value),
    );
  }

  void onLike() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? liked = prefs.getStringList("favourites");
    if (liked == null) {
      List<String> newLiked = [];
      newLiked.add(widget.id);
      prefs.setStringList("favourites", newLiked);
      setState(() {
        isFavourite = true;
      });
    } else {
      if (liked.contains(widget.id)) {
        List<String> newLiked = liked.where((e) => e != widget.id).toList();
        prefs.setStringList("favourites", newLiked);
        setState(() {
          isFavourite = false;
        });
      } else {
        liked.add(widget.id);
        prefs.setStringList("favourites", liked);
        setState(() {
          isFavourite = true;
        });
      }
    }
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
              return Text(name, style: TextStyle(fontFamily: "OldStandard"));
            } else if (future.hasError) {
              return Text('${future.error}');
            }
            return const CircularProgressIndicator();
          },
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40.0), // here the desired height
          child: FutureBuilder(future: reading, builder: (context, future) {
            if (future.hasData) {
              return Row(
                children: <Widget>[
                  if (future.data!.ruLink != null) TextButton(
                    onPressed: () => onClick(future.data!.ruLink as String),
                    child: Text("РУ", style: TextStyle(color: Colors.white),),
                  ),
                  if (future.data!.link != null) TextButton(
                    onPressed: () => onClick(future.data!.link as String),
                    child: Text("ЦС", style: TextStyle(color: Colors.white),),
                  ),
                  if (future.data!.dneslovId != null) IconButton(
                      onPressed: () => Navigator.pushNamed(context, "/saints", arguments: future.data!.dneslovId),
                      icon: Icon(Icons.person, color: Colors.white),
                  ),
                  if (future.data!.bookId != null) IconButton(
                      onPressed: () => Navigator.pushNamed(context, "/library", arguments: future.data!.bookId),
                      icon: Icon(Icons.menu_book, color: Colors.white),
                  ),
                  if (future.data!.dayId != null) IconButton(
                      onPressed: () => Navigator.pushNamed(context, "/days", arguments: future.data!.dayId),
                      icon: Icon(Icons.calendar_month, color: Colors.white),
                  ),
                ],
              );
            }
            return Row(children: []);
          }),
        ),
        actions: <Widget>[
          IconButton(
              onPressed: onLike,
              icon: isFavourite ? Icon(
                Icons.favorite,
                color: Colors.pink,
              ) : Icon(
                Icons.favorite_outline,
              )
          )
        ],
      ),
      body: Container(
        color: StoreProvider.of<AppState>(context).state.settings.backgroundColor,
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
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                            )
                        ),
                      ),
                      Column(
                        children: content.split("\n\n").map((itemContent) =>
                            FusionTextWidgets(
                              text: itemContent,
                              footnotes: future.data?.footnotes??[],
                            ),
                        ).toList(),
                      ),
                      if (future.data!.dneslovId != null) FutureBuilder<DneslovImageListD>(
                          future: dneslovImages,
                          builder: (context, future) {
                            if (future.hasData) {
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
                            return Image.asset("assets/images/trinity.jpeg");
                          }
                      ),
                      if (future.data!.dneslovId == null) Image.asset("assets/images/trinity.jpeg"),
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
              child: Align(
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
            );
          },
        ),
      ),
    );
  }
}