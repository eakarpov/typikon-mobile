import 'dart:convert';

import "package:typikon/dto/search.dart";
import "package:typikon/api/search.dart";

Future<List<SearchBookText>> getSearchResult(String? query) async {
  if (query is String) {
    final response = await searchString(query);
    print(response.body);

    if (response.statusCode == 200) {
      return SearchResults.fromJson(jsonDecode(response.body)).texts;
    } else {
      throw Exception('Не получены результаты');
    }
  } else {
    return SearchResults.empty().texts;
  }
}