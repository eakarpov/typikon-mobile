import "package:typikon/dto/book.dart";
import 'package:shared_preferences/shared_preferences.dart';

import "package:typikon/apiMapper/library.dart";

Future<BookWithTexts> getFavourites() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> liked = prefs.getStringList("favourites") ?? [];
  return getBatchTexts(liked);
}