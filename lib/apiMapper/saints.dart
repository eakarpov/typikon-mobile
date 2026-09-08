import 'dart:convert';

import 'package:typikon/api/dneslov/memories.dart';
import 'package:typikon/api/saints.dart';
import 'package:typikon/dto/saint.dart';

import 'v2/errors.dart';

/// Страница святого собирается из двух источников, и они грузятся врозь.
///
/// Раньше запросов было четыре, и все подряд: dneslov ради номера по слугу,
/// наш v1 за текстами, наш v1 за упоминаниями, dneslov снова за житием. Теперь
/// два, и они идут параллельно — досье наше, житие стороннее.
///
/// Врозь не ради скорости, а ради того, что показывать при неудаче: dneslov
/// молчит заметно чаще нас, и его молчание не должно уносить с собой имя
/// святого, дни памяти и тексты службы.
Future<SaintDossier> getSaintDossier(String address) async {
  final response = await fetchSaintDossier(address);
  if (response.statusCode == 200) {
    return SaintDossier.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось загрузить сведения о святом");
}

/// Житие со стороннего dneslov.org.
///
/// Адрес у dneslov свой — номер святцев, — и наш слуг ему незнаком. Спрашивать
/// наугад нельзя: на неизвестный адрес dneslov не отвечает `404`, а держит
/// соединение открытым до нашего таймаута, и — проверено — следующие запросы к
/// нему на это время встают тоже. Один заведомо напрасный запрос обходится не
/// в шесть своих секунд, а в житие, которое после него уже не успеет прийти.
///
/// Поэтому: номер — идём сразу, не номер — берём номер у досье. Для перехода из
/// текста корпуса (там ссылки номерами) житие грузится вровень с досье; для
/// перехода из святцев — следом за ним.
Future<SaintLife> getSaintLife(String address, {Future<SaintDossier>? dossier}) async {
  if (_isDneslovId(address) || dossier == null) return _life(address);

  final external = (await dossier).dneslovId;
  if (external == null) {
    throw Exception("Житие не найдено: у записи нет номера в святцах");
  }

  return _life(external);
}

/// Номера святцев — целые числа, наши слуги — нет. Различить их по виду можно
/// потому, что вид у них и правда разный, а не потому, что так удобнее.
bool _isDneslovId(String address) => int.tryParse(address) != null;

Future<SaintLife> _life(String address) async {
  final byAddress = await fetchMemoryById(address);
  if (byAddress.statusCode != 200) {
    throw Exception("Житие не найдено: dneslov ответил ${byAddress.statusCode}");
  }

  final slug = jsonDecode(byAddress.body)["slug"];
  if (slug is! String || slug.isEmpty) {
    throw Exception("Житие не найдено: у памяти нет слуга на dneslov");
  }

  final info = await fetchMemoryInfoBySlug(slug);
  if (info.statusCode != 200) {
    throw Exception("Житие не загрузилось: dneslov ответил ${info.statusCode}");
  }

  return SaintLife.fromJson(slug, jsonDecode(info.body));
}
