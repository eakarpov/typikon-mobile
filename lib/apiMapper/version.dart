import 'dart:convert';

import 'package:typikon/api/version.dart';
import 'package:typikon/dto/version.dart';

Future<Version> getVersion() async {
  final response = await fetchVersion();

  if (response.statusCode == 200) {
    return Version.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Не получена версия');
  }
}