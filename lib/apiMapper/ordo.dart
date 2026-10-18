import 'dart:convert';
import 'package:http/http.dart' as http;

import '../api/ordo.dart';
import '../dto/ordo.dart';
import '../dto/ordo_services.dart';
import 'v2/errors.dart';

/// Кафизмы уставного дня («сегодня по уставу»).
///
/// `null` — пометки «сегодня» не будет: раздел ordo закрыт у ключа, сервер
/// старый, сети нет. Это прибавка к списку кафизм, а не сам список, и ради
/// неё ронять экран незачем — читают Псалтирь не по пометкам.
Future<OrdoKafizmy?> getTodayKafizmy([DateTime? date]) async {
  try {
    final response = await fetchOrdoDay(date ?? DateTime.now());
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return OrdoDay.fromJson(Map<String, dynamic>.from(decoded)).kafizmy;
  } catch (_) {
    return null;
  }
}

/// Отказ раздела не отзывает общий ключ приложения.
Future<OrdoServices> getOrdoServices(
  DateTime date, {
  Future<http.Response> Function(DateTime)? fetch,
}) async {
  final response = await (fetch ?? fetchOrdoServices)(date);
  if (response.statusCode == 401 || response.statusCode == 403) {
    throw const ApiUnauthorizedException(
      'Раздел «Служба дня» недоступен. Обновите приложение.',
    );
  }
  if (response.statusCode != 200) {
    throwV2Error(response, 'Не удалось открыть службу дня');
  }
  return OrdoServices.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
}
