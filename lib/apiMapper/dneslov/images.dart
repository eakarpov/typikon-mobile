import 'dart:convert';

import 'package:typikon/api/dneslov/images.dart';
import 'package:typikon/dto/dneslov/images.dart';

Future<DneslovImageListD> fetchDneslovImagesD(String dneslovId) async {
  print(dneslovId);
  final imageResponse = await fetchDneslovImages(dneslovId);
  print(imageResponse);

  if (imageResponse.statusCode == 200) {
    return DneslovImageListD.fromJson(jsonDecode(imageResponse.body));
  } else {
    throw Exception('Failed to load images');
  }
}