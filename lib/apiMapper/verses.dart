import 'dart:convert';

import '../api/verses.dart';
import '../dto/verse.dart';

Future<VerseList> getVerses(String textId) async {
  final response = await fetchVerses(textId);

  if (response.statusCode == 200) {
    return VerseList.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не удалось загрузить текст Библии');
  }
}
