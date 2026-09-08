import 'package:http/http.dart' as http;

import 'cached_fetch.dart';
import 'v2/request.dart';

/// День наряду со своими чтениями.
///
/// **Тела текстов просим прямо здесь (`expand=content`).** По умолчанию вторая
/// версия API отдаёт одни описания — так верно для страницы сайта, которая
/// ведёт в текст ссылкой. Экран дня в приложении день читает, и без тел ему
/// достался бы запрос на каждый текст: в ином дне их полсотни, и на мобильной
/// сети это разница между «открылось» и «крутится».
///
/// Спрашивается по псевдониму (`january-01`, `pascha`): вторая версия API берёт
/// его, и он же стоит в адресах страниц сайта.
Future<http.Response> fetchDay(String alias) {
  return cachedFetch(
    'days:$alias',
    () => v2Get(v2Uri('/days/$alias', {'expand': 'content'})),
    ttl: const Duration(hours: 24),
  );
}
