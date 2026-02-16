import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import "package:google_fonts/google_fonts.dart";
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_saver_ffi/file_saver_ffi.dart';
import 'package:path/path.dart';
import "package:path_provider/path_provider.dart";
import 'package:epub_pro/epub_pro.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:typikon/main.dart';
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
          ),
          FutureBuilder<Reading>(
            future: reading,
            builder: (context, future) {
              if (future.hasData) {
                String name = future.data!.name;
                String content = future.data!.content;
                return TextButton(
                  // icon: Icon(
                  //   Icons.file_download,
                  //   color: Colors.white,
                  // ),
                  child: Text("fb2", style: TextStyle(color: Colors.white)),
                  onPressed: () async{
                    // var book = EpubBook(
                    //     title: "Test",
                    //     author: "No author",
                    //     content: EpubContent(
                    //       allFiles: {},
                    //     ),
                    //     schema: EpubSchema(
                    //       package: EpubPackage(
                    //         version: EpubVersion.epub2,
                    //         metadata: EpubMetadata(),
                    //         manifest: EpubManifest(),
                    //         spine: EpubSpine(
                    //           ltr: true,
                    //           tableOfContents: "",
                    //         ),
                    //         guide: EpubGuide(),
                    //       ),
                    //     ),
                    //     chapters: [
                    //       EpubChapter(
                    //         title: "Chapter",
                    //         htmlContent: "<div>Test something</div>",
                    //       )
                    //     ]
                    // );
                    // var bytes = await rootBundle.load('assets/English-cyrillic.epub');
                    // var p = ByteData.sublistView(bytes).buffer.asUint8List();
                    // // var bytes = File('assets/English-cyrillic.epub').readAsBytesSync();
                    // var b = await EpubReader.readBook(p);
                    // print(b.schema);
                    // print(b.schema!.contentDirectoryPath);
                    // var bb = EpubBook(b);

                    //
                    // var w = EpubWriter.writeBook(b);
                    // if (w != null) {
                    //   print(w);
                    //   // await file.writeAsBytes(w);
                    //   // await FileSaver.instance.saveFile(
                    //   //   name: "hello.epub",
                    //   //   bytes: Uint8List.fromList(w),
                    //   //   fileExtension: "epub",
                    //   // );
                    //   final uri = await FileSaver.instance.saveBytesAsync(
                    //       fileName: 'hello',
                    //       bytes: Uint8List.fromList(w),
                    //       fileType: CustomFileType(ext: 'epub', mimeType: 'application/epub+zip')
                    //   );
                    //   print(uri);
                    // }

                    String fb2Content = """<?xml version="1.0" encoding="UTF-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
<description>
  <title-info>
    <genre>poetry</genre>
    <author><first-name>No</first-name><last-name>author</last-name></author>
    <book-title>${name}</book-title>
    <lang>en</lang>
  </title-info>
  <document-info>
    <author><nickname>Creator</nickname></author>
    <program-used>Dart Script</program-used>
    <date>2026-02-16</date>
    <id>12345</id>
    <version>1.0</version>
  </document-info>
</description>
<body>
  <section>
    <title>${name}</title>
    <p>${content}</p>
  </section>
</body>
</FictionBook>
""";

                    Uri uri = await FileSaver.instance.saveBytesAsync(
                        fileName: "Из уставных чтений",
                        bytes: utf8.encode(fb2Content),
                        fileType: CustomFileType(ext: 'fb2', mimeType: 'application/x-fictionbook'),
                        conflictResolution: ConflictResolution.autoRename,
                    );
                    print(uri.toString());
                    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
                      'updateChannelId',
                      'updateNotificationChannel',
                      channelDescription: 'Notifications about update',
                      importance: Importance.max,
                      priority: Priority.high,
                      ticker: "update version ticker",
                    );
                    var iOSPlatformChannelSpecifics = new DarwinNotificationDetails();

                    // initialise channel platform for both Android and iOS device.
                    var platformChannelSpecifics = new NotificationDetails(
                        android: androidPlatformChannelSpecifics,
                        iOS: iOSPlatformChannelSpecifics
                    );

                    await flutterLocalNotificationsPlugin.show(id++,
                      'Уставные чтения',
                      'Скачался файл. Для октрытия нажмите.',
                      platformChannelSpecifics, payload: "download - ${uri.toString()}",
                    );

                    // final pdf = pw.Document();
                    // final fileStr = await rootBundle.load('assets/fonts/OldStandardTT-Regular.ttf');
                    // print(fileStr);
                    // // final Uint8List fontData = File('OldStandard-Regular.otf').readAsBytesSync();
                    // final ttf = pw.Font.ttf(fileStr);
                    //
                    // pdf.addPage(pw.MultiPage(
                    //     maxPages: 4,
                    //     pageFormat: PdfPageFormat.a4,
                    //     build: (pw.Context context) {
                    //       return Wrap(pw.Text(
                    //         content,
                    //         style: pw.TextStyle(font: ttf, fontSize: 40),
                    //       )); // Center
                    //     })); // Page
                    // final bytes = await pdf.save();
                    // final uri = await FileSaver.instance.saveBytesAsync(
                    //     fileName: name,
                    //     bytes: bytes,
                    //     fileType: CustomFileType(ext: 'pdf', mimeType: 'application/pdf')
                    // );
                    // print(uri);

                    // Directory? appDocDirectory = await getExternalStorageDirectory();
                    // if (appDocDirectory != null) {
                    // File file = File(join(appDocDirectory.path, "hello.epub"));
                    // await file.create();
                    // print(file);
                    // }
                  },
                );
              } else if (future.hasError) {
                return Text('${future.error}');
              }
              return const CircularProgressIndicator();
            },
          ),
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
                      future.data!.newUi ? (
                        SizedBox(
                          height: 350.0,
                          child: Markdown(
                            data: content,
                          ),
                        )
                      ) : (
                          Column(
                            children: content.split("\n\n").map((itemContent) =>
                                FusionTextWidgets(
                                  text: itemContent,
                                  footnotes: future.data?.footnotes??[],
                                  fontFamily: future.data!.csSource ? "Monomakh" : "OldStandard",
                                ),
                            ).toList(),
                          )
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