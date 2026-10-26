import 'dart:convert';
import 'package:http/http.dart' as http;
import '../cached_fetch.dart';
import '../constants.dart';
import '../client.dart';
import '../../dto/dneslov/images.dart';

Future<http.Response> fetchDneslovImages(
  String dneslovId, {
  http.Client? client,
}) {
  return cachedFetch(
    'dneslov-images:v3:$dneslovId',
    () async {
      final uri = Uri.parse(
        '$dneslovBaseUrl/api/v1/images.json',
      ).replace(queryParameters: {'m': dneslovId});
      final rows = <dynamic>[];
      int? total;
      var offset = 0;
      for (var page = 0; page < 50; page++) {
        final response = await (client ?? apiClient)
            .get(uri, headers: {'Range': 'records=$offset-${offset + 100}'})
            .timeout(dneslovTimeout);
        if (response.statusCode == 204) {
          if (total != null && offset < total)
            throw const FormatException('Неполный список изображений');
          return _imagesResponse(rows);
        }
        if (response.statusCode != 200 && response.statusCode != 206)
          return response;
        final decoded = jsonDecode(response.body);
        final list = decoded is List
            ? decoded
            : decoded is Map && decoded['list'] is List
            ? decoded['list'] as List
            : null;
        if (list == null)
          throw const FormatException('Неверный список изображений');
        final range = RegExp(
          r'^records\s+(\d+)-\d+/(\d+|\*)$',
        ).firstMatch(response.headers['content-range'] ?? '');
        if (range != null && int.parse(range[1]!) != offset) {
          throw const FormatException(
            'Днеслов не вернул следующую страницу изображений',
          );
        }
        if (range != null && range[2] != '*') total = int.parse(range[2]!);
        rows.addAll(list);
        offset += list.length;
        // Their end index can exceed the actual last record; count the body.
        if (total != null && offset >= total) return _imagesResponse(rows);
        if (range == null || (total == null && list.length < 100))
          return _imagesResponse(rows);
        if (list.isEmpty)
          throw const FormatException('Неполный список изображений');
      }
      throw const FormatException('Слишком много страниц изображений');
    },
    ttl: const Duration(hours: 24),
    isCacheable: (body) {
      DneslovImageListD.fromJson(jsonDecode(body));
      return true;
    },
  );
}

http.Response _imagesResponse(List<dynamic> rows) => http.Response(
  jsonEncode(rows),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
