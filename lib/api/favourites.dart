import 'dart:convert';

import 'package:http/http.dart' as http;

import 'client.dart';
import 'constants.dart';
import '../store/auth_token.dart';

/// Избранное на сервере. Всё — только для вошедших: userId берётся из сессии,
/// в теле его нет.

Future<http.Response> fetchFavourites() async {
  return apiClient.get(
    Uri.parse('$apiBaseUrl/api/favourites'),
    headers: await authHeader(),
  ).timeout(apiTimeout);
}

Future<http.Response> addFavourite(String textId) async {
  return apiClient.post(
    Uri.parse('$apiBaseUrl/api/favourites'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      ...await authHeader(),
    },
    body: jsonEncode(<String, dynamic>{'textId': textId}),
  ).timeout(apiTimeout);
}

Future<http.Response> removeFavourite(String textId) async {
  return apiClient.delete(
    Uri.parse('$apiBaseUrl/api/favourites/$textId'),
    headers: await authHeader(),
  ).timeout(apiTimeout);
}

/// Первый вход с устройства, где избранное уже накопилось: список вливается в
/// серверный, ничего не затирая, и в ответ приходит объединённый.
Future<http.Response> mergeFavourites(List<String> textIds) async {
  return apiClient.post(
    Uri.parse('$apiBaseUrl/api/favourites/merge'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      ...await authHeader(),
    },
    body: jsonEncode(<String, dynamic>{'textIds': textIds}),
  ).timeout(apiTimeout);
}
