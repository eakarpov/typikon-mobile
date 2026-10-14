import 'dart:convert';

import 'package:typikon/api/dneslov/images.dart';
import 'package:typikon/dto/dneslov/images.dart';

Future<DneslovImageListD> fetchDneslovImagesD(String dneslovId) async {
  final imageResponse = await fetchDneslovImages(dneslovId);

  if (imageResponse.statusCode < 300) { // Приходит 206 сейчас
    return DneslovImageListD.fromJson(jsonDecode(imageResponse.body));
  } else {
    throw Exception('Failed to load images');
  }
}