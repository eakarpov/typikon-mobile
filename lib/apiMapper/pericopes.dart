import 'dart:convert';

import '../api/pericopes.dart';
import '../dto/paged.dart';
import '../dto/pericope.dart';
import 'v2/errors.dart';

Future<Paged<PericopeEntry>> getPericopes({
  String? source,
  String? book,
  int offset = 0,
}) async {
  final response = await fetchPericopes(source: source, book: book, offset: offset);
  if (response.statusCode == 200) {
    return Paged.fromJson<PericopeEntry>(jsonDecode(response.body), PericopeEntry.fromJson);
  }
  throwV2Error(response, "Не удалось загрузить указатель зачал");
}

Future<PericopeReading> getPericope(String id, {String? lang}) async {
  final response = await fetchPericope(id, lang: lang);
  if (response.statusCode == 200) {
    return PericopeReading.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось загрузить зачало");
}
