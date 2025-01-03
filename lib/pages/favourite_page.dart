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
  late Future<List<BookText>> favourites;

  @override
  void initState() {
    super.initState();
    favourites = getFavourites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Избранное"),
      ),
      body: Container(
        color: const Color(0xffffffff),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FutureBuilder<List<BookText>>(
          future: favourites,
          builder: (context, future) {
            if (future.hasData) {
              return Text('');
              // List<Month> list = future.data!.list;
              // return ListView.builder(
              //   scrollDirection: Axis.vertical,
              //   itemCount: list.length,
              //   itemBuilder: (context, index) {
              //     final item = list[index];
              //     String locale = Localizations.localeOf(context).languageCode;
              //     DateTime now = DateTime.now();
              //     DateTime newDate =  DateTime.utc(now.year, item.value ?? 0);
              //     String month = DateFormat.MMMM(locale).format(newDate);
              //     return Container(
              //       child: ListTile(
              //         title: Text(month),
              //         onTap: () => {
              //           Navigator.pushNamed(context, "/reading", arguments: item.id)
              //         },
              //       ),
              //     );
              //   },
              // );
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