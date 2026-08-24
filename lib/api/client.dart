import 'package:http/http.dart' as http;

import 'constants.dart';

/// HTTP-клиент приложения.
///
/// Единственная его задача — представляться серверу заголовком `X-Typikon-App`.
/// Сервер по нему считает, сколько запросов к устаревшей первой версии API идёт
/// от приложения, а сколько от кого-то ещё: пока доля «кого-то ещё» велика,
/// закрывать v1 нельзя, иначе разом отвалятся все, кто не обновился.
///
/// Заголовок ставится не на каждый вызов вручную, а здесь, и только для запросов
/// к нашему серверу: dneslov.org — чужой сайт, и представляться ему незачем.
///
/// Чтобы новый вызов автоматически получил заголовок, обращайтесь через [apiClient],
/// а не через `http.get` напрямую.
class _TypikonClient extends http.BaseClient {
  _TypikonClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_isOwnHost(request.url.host)) {
      request.headers[appHeaderName] = appVersion;
    }
    return _inner.send(request);
  }

  bool _isOwnHost(String host) =>
      host == 'typikon.su' || host.endsWith('.typikon.su');

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Общий клиент приложения. Живёт всё время работы программы — соединения
/// переиспользуются, отдельно закрывать его не нужно.
final http.Client apiClient = _TypikonClient(http.Client());

/// Тот же клиент поверх произвольного нижележащего — нужен тестам, чтобы
/// проверить подстановку заголовка, не выходя в сеть.
http.Client createApiClient(http.Client inner) => _TypikonClient(inner);
