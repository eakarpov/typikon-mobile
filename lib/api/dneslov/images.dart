import 'package:http/http.dart' as http;

import '../cached_fetch.dart';
import '../constants.dart';

Future<http.Response> fetchDneslovImages(String dneslovId) {
  return cachedFetch(
    'dneslov-images:$dneslovId',
    () => http.get(Uri.parse('$dneslovBaseUrl/api/v1/images.json?m=$dneslovId')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}

Future<http.Response> fetchDneslovRoundels(String dneslovId) {
  return cachedFetch(
    'dneslov-roundels:$dneslovId',
    () => http.get(Uri.parse('$dneslovBaseUrl/api/v1/roundels.json?m=$dneslovId')).timeout(apiTimeout),
    ttl: const Duration(hours: 24),
  );
}
