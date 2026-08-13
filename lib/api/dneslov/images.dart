import 'package:http/http.dart' as http;

import '../constants.dart';

Future<http.Response> fetchDneslovImages(String dneslovId) {
  return http.get(Uri.parse('$dneslovBaseUrl/api/v1/images.json?m=$dneslovId')).timeout(apiTimeout);
}

Future<http.Response> fetchDneslovRoundels(String dneslovId) {
  return http.get(Uri.parse('$dneslovBaseUrl/api/v1/roundels.json?m=$dneslovId')).timeout(apiTimeout);
}
