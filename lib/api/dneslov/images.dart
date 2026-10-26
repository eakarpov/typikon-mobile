import 'package:http/http.dart' as http;

import '../cached_fetch.dart';
import '../constants.dart';
import '../client.dart';
import '../../dto/dneslov/images.dart';
import 'dart:convert';

Future<http.Response> fetchDneslovImages(
  String dneslovId, {
  http.Client? client,
}) {
  return cachedFetch(
    'dneslov-images:v2:$dneslovId',
    () async {
      final uri = Uri.parse(
        '$dneslovBaseUrl/api/v1/images.json',
      ).replace(queryParameters: {'m': dneslovId});
      final response = await (client ?? apiClient)
          .get(uri)
          .timeout(dneslovTimeout);
      if (response.statusCode == 204) return http.Response('[]', 200);
      // Dneslov uses 206 for successful image lists.
      if (response.statusCode == 206) {
        return http.Response.bytes(
          response.bodyBytes,
          200,
          headers: response.headers,
        );
      }
      return response;
    },
    ttl: const Duration(hours: 24),
    isCacheable: (body) {
      DneslovImageListD.fromJson(jsonDecode(body));
      return true;
    },
  );
}
