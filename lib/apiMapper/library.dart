import 'dart:convert';

import '../api/library.dart';
import '../dto/book.dart';
import '../dto/library.dart';

Future<BookList> getBooks() async {
  final response = await fetchBooks();

  if (response.statusCode == 200) {
    return BookList.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получены книги');
  }
}

Future<BookWithTexts> getBook(String id) async {
  final response = await fetchBook(id);

  if (response.statusCode == 200) {
    return BookWithTexts.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получена книга');
  }
}

Future<BookWithTexts> getBatchTexts(List<String> ids) async {
  final response = await batchTexts(ids);

  if (response.statusCode == 200) {
    return BookWithTexts.fromJsonToList(jsonDecode(response.body));
  } else {
    if (ids.length == 0) {
      return BookWithTexts.fromJsonToList([]);
    }
    throw Exception('Не получена книга');
  }
}