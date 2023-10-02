import 'dart:convert';

import '../api/library.dart';
import '../dto/book.dart';
import '../dto/library.dart';

Future<BookList> getBooks() async {
  final response = await fetchBooks();

  if (response.statusCode == 200) {
    return BookList.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load album');
  }
}

Future<BookWithTexts> getBook(String id) async {
  final response = await fetchBook(id);

  if (response.statusCode == 200) {
    return BookWithTexts.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load album');
  }
}