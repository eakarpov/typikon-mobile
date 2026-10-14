import 'dart:convert';

import 'package:typikon/api/saints.dart';
import 'package:typikon/dto/saint.dart';

import 'v2/errors.dart';

/// Страница святого собирается из двух источников, и они грузятся врозь.
///
/// Два параллельных запроса к нашему серверу: досье — запись каталога, житие —
/// прокси в каталог памятей. Резолв адреса (слug или номер святцев) лежит на
/// сервере, клиенту о нём знать не нужно.
///
/// Врозь не ради скорости, а ради того, что показывать при неудаче: жития нет у
/// всякой записи, и это не должно уносить с собой имя святого, дни памяти и
/// тексты службы.
Future<SaintDossier> getSaintDossier(String address) async {
  final response = await fetchSaintDossier(address);
  if (response.statusCode == 200) {
    return SaintDossier.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось загрузить сведения о святом");
}

/// Житие: один запрос, адрес — как у досье (слug или номер святцев).
///
/// Отказ «жития нет / не связано / источник недоступен» сервер подписывает
/// сам — сообщение доезжает до экрана через [throwV2Error] как есть.
Future<SaintLife> getSaintLife(String address) async {
  final response = await fetchSaintLife(address);
  if (response.statusCode == 200) {
    return SaintLife.fromJson(jsonDecode(response.body));
  }
  throwV2Error(response, "Не удалось загрузить житие");
}
