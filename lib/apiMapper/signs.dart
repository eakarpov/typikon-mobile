
import 'dart:convert';

import 'package:typikon/api/signs.dart';
import 'package:typikon/dto/signs.dart';

Future<SignsList> getSigns({int page = 1}) async {
  final response = await fetchSigns(page: page);

  if (response.statusCode == 200) {
    return SignsList.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получены знаки');
  }
}
