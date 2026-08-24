import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:typikon/api/client.dart';
import 'package:typikon/api/constants.dart';

// Заголовок X-Typikon-App нужен серверу, чтобы отличать приложение от прочих
// клиентов первой версии API и понимать, когда её можно закрывать. Если он
// перестанет уходить, сервер решит, что старых клиентов не осталось, — и закроет
// v1 под работающим приложением. Поэтому проверяем.

void main() {
  late List<http.BaseRequest> seen;
  late http.Client client;

  setUp(() {
    seen = [];
    client = createApiClient(MockClient((request) async {
      seen.add(request);
      return http.Response('{}', 200);
    }));
  });

  test('запрос к нашему серверу несёт заголовок с версией', () async {
    await client.get(Uri.parse('$apiBaseUrl/api/v1/months'));

    expect(seen.single.headers[appHeaderName], appVersion);
  });

  test('версия совпадает с той, что объявлена в приложении', () {
    // Строка уходит в счётчики на сервере, поэтому пустой или заглушечной быть не должна.
    expect(appVersion, isNotEmpty);
    expect(appVersion, matches(RegExp(r'^\d+\.\d+\.\d+')));
  });

  test('чужому серверу не представляемся', () async {
    await client.get(Uri.parse('$dneslovBaseUrl/api/v0/memories/1.json'));

    expect(seen.single.headers.containsKey(appHeaderName), isFalse,
        reason: 'dneslov.org — сторонний сайт, ему наш заголовок ни к чему');
  });

  test('похожий чужой домен не считается своим', () async {
    // Проверка хоста должна цепляться за границу имени, а не за вхождение строки.
    await client.get(Uri.parse('https://typikon.su.example.com/api/v1/months'));

    expect(seen.single.headers.containsKey(appHeaderName), isFalse);
  });

  test('поддомен нашего сервера считается своим', () async {
    await client.get(Uri.parse('https://www.typikon.su/api/v1/months'));

    expect(seen.single.headers[appHeaderName], appVersion);
  });

  test('заголовок не затирает остальные', () async {
    await client.post(
      Uri.parse('$apiBaseUrl/api/v1/texts/batch'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );

    expect(seen.single.headers['Content-Type'], contains('application/json'));
    expect(seen.single.headers[appHeaderName], appVersion);
  });
}
