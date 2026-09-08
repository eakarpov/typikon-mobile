import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../store/auth_token.dart';
import '../client.dart';
import '../constants.dart';
import 'api_key.dart';
import 'error_body.dart';

/// Обращение ко второй версии API.
///
/// Всё, что здесь есть, — сборка адреса из одного корня и подстановка ключа.
/// Слой остаётся тем же `lib/api/*`: возвращаем сырой `http.Response` и ничего
/// не бросаем; разбор и исключения живут в `lib/apiMapper/v2/errors.dart`.
///
/// Заведено сейчас, когда потребитель один (раздел Библии), нарочно: следом по
/// v2 пойдут месяцы, дни, книги, тексты, знаки и поиск — и тогда это была бы
/// одна и та же правка в восьми местах вместо одного.

/// Адрес ручки v2. Параметры собираются через `Uri.replace`, а не подстановкой
/// в строку: коды изданий идут списком через запятую, и однажды ручная склейка
/// дала бы пробел или незакодированный `&` внутри значения. Та же причина
/// записана в `lib/api/search.dart`.
Uri v2Uri(String path, [Map<String, String>? query]) {
  final uri = Uri.parse('$apiBaseUrl/api/v2$path');
  if (query == null || query.isEmpty) return uri;
  return uri.replace(queryParameters: query);
}

/// GET к v2 с ключом, если он есть.
///
/// Ходим через [apiClient], а не `http.get`: иначе перестанет уходить
/// `X-Typikon-App`, по которому веб считает долю приложения среди клиентов
/// первой версии и решает, можно ли её закрывать.
///
/// **Отказ ключа не ломает раздел.** Ответил сервер `401` или `403` на запрос с
/// ключом — считаем ключ негодным до перезапуска и повторяем тот же запрос
/// анонимом. Отзыв ключа тогда понижает квоту, а не гасит раздел у всех
/// установленных копий разом.
///
/// **Но не везде.** Поиск по песнопениям и по зачинам живёт в разделе доступа
/// `search`, единственном, который анониму не полагается вовсе. Повторять там
/// нечего: второй запрос вернёт тот же `401`, зато ключ окажется помечен
/// негодным из-за ручки, которая его отвергла не потому, что он плох. Такие
/// вызовы передают [retryAnonymously] `false` и получают отказ сервера как есть —
/// он и написан для человека: «Этот раздел доступен по ключу».
///
/// **И не на всякий отказ.** Отказать `401`-м сервер может и не ключу: у личных
/// разделов за ключом стоит ещё и сессия, и её протухание приходит кодом
/// `session_required`. Ключ тут ни при чём, а сессия сайта живёт час — приняв
/// одно за другое, приложение объявляло бы общий ключ негодным по нескольку раз
/// на дню и уводило бы в анонимы Библию, поиск и календарь заодно. Поэтому
/// негодным ключ считается только на кодах, которые про него и написаны.
///
/// [client] подменяется тестами; в приложении всегда общий [apiClient].
Future<http.Response> v2Get(
  Uri uri, {
  http.Client? client,
  bool retryAnonymously = true,
}) async {
  final http.Client transport = client ?? apiClient;
  final headers = apiKeyHeaders();

  final response = await transport.get(uri, headers: headers).timeout(apiTimeout);
  if (headers.isEmpty) return response;
  if (!_refusesKey(response)) return response;
  if (!retryAnonymously) return response;

  markApiKeyRefused('сервер ответил ${response.statusCode} на запрос с ключом');
  return transport.get(uri).timeout(apiTimeout);
}

/// Отказали ли **ключу**.
///
/// Сервер называет причину сам: `unauthorized` — ключа нет, он не признан,
/// отозван или просрочен; `forbidden` — ключ настоящий, но раздела не даёт.
/// Всё прочее под теми же кодами состояния — не про ключ.
///
/// Тело без кода считаем отказом ключу: так вело себя приложение до появления
/// личных разделов, и менять это на «не трогать ключ» значило бы перестать
/// замечать настоящий отзыв там, где ответ пришёл не от нашего сервера.
bool _refusesKey(http.Response response) {
  if (response.statusCode != 401 && response.statusCode != 403) return false;

  final code = v2ErrorCode(response);
  return code == null || code == 'unauthorized' || code == 'forbidden';
}

/// Запрос к личной ручке v2 — с ключом **и** с сессией.
///
/// Три отличия от [v2Get], и все три об одном.
///
/// **Сессия ездит своим заголовком.** Ключ идёт в `Authorization`, сессия — в
/// `Cookie`; каналы разные, столкновения нет (см. `api_key.dart`).
///
/// **Анонимного повтора нет.** Личный раздел анониму не отвечает вовсе, и второй
/// запрос вернул бы тот же отказ. Та же причина, по которой его нет у поиска.
///
/// **Ключ негодным не объявляется никогда.** Отказ личной ручки — это почти
/// всегда протухшая сессия, а не плохой ключ; починка сессии живёт в
/// `withSession`, и лезть сюда ей незачем.
Future<http.Response> v2Send(
  String method,
  Uri uri, {
  Object? body,
  http.Client? client,
}) async {
  final http.Client transport = client ?? apiClient;
  final headers = <String, String>{
    ...apiKeyHeaders(),
    ...await authHeader(),
    if (body != null) 'Content-Type': 'application/json; charset=utf-8',
  };

  final request = http.Request(method, uri)..headers.addAll(headers);
  if (body != null) request.bodyBytes = utf8.encode(jsonEncode(body));

  final streamed = await transport.send(request).timeout(apiTimeout);
  return http.Response.fromStream(streamed);
}
