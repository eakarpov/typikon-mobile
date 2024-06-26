import 'package:http/http.dart' as http;

Future<http.Response> fetchDneslovImages(String dneslovId) {
  return http.get(Uri.parse('http://dneslov.org/api/v1/images.json?m=$dneslovId'));
}

