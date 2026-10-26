import '../dto/dneslov/images.dart';
import 'dneslov/images.dart';
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

/// Reuse the Prologue image source; prefer the server's saved CDN list.
Future<DneslovImageListD> getSaintIcons(
  SaintDossier dossier, {
  Future<DneslovImageListD> Function(String)? fetch,
}) async {
  if (dossier.images.isNotEmpty) return DneslovImageListD(list: dossier.images);
  final ids = {
    ...dossier.dneslovIds,
    if (dossier.externals['dneslov'] != null) dossier.externals['dneslov']!,
  };
  if (ids.isEmpty) return const DneslovImageListD(list: []);
  final images = <DneslovImageDItem>[];
  var succeeded = false;
  Object? error;
  // Do not flood the source when several memories refer to the same saint.
  for (final id in ids) {
    try {
      images.addAll((await (fetch ?? fetchDneslovImagesD)(id)).list);
      succeeded = true;
    } catch (e) {
      error = e;
    }
  }
  if ((!succeeded || images.isEmpty) && error != null) throw error;
  final seen = <String>{};
  return DneslovImageListD(list: images.where((i) => seen.add(i.url)).toList());
}
