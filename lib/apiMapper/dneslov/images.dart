import 'dart:convert';

import 'package:typikon/api/dneslov/images.dart';
import 'package:typikon/dto/dneslov/images.dart';
import 'package:typikon/dto/dneslov/roundels.dart';

Future<DneslovImageListD> fetchDneslovImagesD(String dneslovId) async {
  final imageResponse = await fetchDneslovImages(dneslovId);

  if (imageResponse.statusCode == 200) {
    return DneslovImageListD.fromJson(jsonDecode(imageResponse.body));
  } else {
    throw Exception('Failed to load images');
  }
}

Future<DneslovRoundelsListD> fetchDneslovRoundelsD(String? dneslovId) async {
  if (dneslovId == null || dneslovId == "") {
    throw Exception('Failed to load images');
  }
  final imageResponse = await fetchDneslovRoundels(dneslovId);

  if (imageResponse.statusCode == 200) {
    return DneslovRoundelsListD.fromJson(jsonDecode(imageResponse.body));
  } else {
    throw Exception('Failed to load images');
  }
}