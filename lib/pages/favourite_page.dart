import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:typikon/apiMapper/favourites.dart';
import 'package:typikon/dto/book.dart';

class FavouritePage extends StatefulWidget {
  const FavouritePage(context, {super.key});

  @override
  State<FavouritePage> createState() => _FavouritePageState();
}

class _FavouritePageState extends State<FavouritePage> {
  late Future<BookWithTexts> favourites;

  @override
  void initState() {
    super.initState();
    favourites = getFavourites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Избранное", style: TextStyle(fontFamily: "OldStandard")),
      ),
      body: Container(
        color: const Color(0xffffffff),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<BookWithTexts>(
          future: favourites,
          builder: (context, future) {
            if (future.hasData) {
              List<BookText> list = future.data!.texts;
              if (list.isEmpty) {
                return Container(
                  color: const Color(0xffffffff),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: const Text("Вы еще ничего не добавили в избранное")
                    ),
                  ),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Container(
                    child: ListTile(
                      leading: Icon(
                        Icons.favorite,
                        color: Colors.pink,
                        size: 32.0,
                        semanticLabel: 'Text to announce in accessibility modes',
                      ),
                      title: Text(
                          item.name,
                          style: TextStyle(fontFamily: "OldStandard")),
                      onTap: () =>
                      {
                        Navigator.pushNamed(
                            context, "/reading", arguments: item.id)
                      },
                    ),
                  );
                },
              );
            } else if (future.hasError) {
              return Text('${future.error}');
            }
            return Container(
              color: const Color(0xffffffff),
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
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