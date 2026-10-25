import 'dart:convert';
import 'package:http/http.dart' as http;

import '../api/ordo.dart';
import '../dto/ordo.dart';
import '../dto/ordo_services.dart';
import '../domain/ordo_package.dart';
import 'v2/errors.dart';
import 'ordo_scripture.dart';

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
      'Сервер отказал в загрузке последования. Попробуйте позже или откройте файл .ordo.',
    );
  }
  if (response.statusCode != 200) {
    if (response.statusCode == 503) {
      throw const ApiUnavailableException(
        'Серверная сборка последований временно недоступна. '
        'Повторите позже или откройте скачанный файл .ordo.',
      );
    }
    throwV2Error(response, 'Не удалось открыть службу дня');
  }
  if (response.bodyBytes.length >= 2 &&
      response.bodyBytes[0] == 0x50 &&
      response.bodyBytes[1] == 0x4b) {
    return (await resolveOrdoScripture(
      OrdoPackage.decode(response.bodyBytes),
    )).reading;
  }
  return OrdoServices.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
}

Future<int?> getOrdoTone(DateTime date) async {
  try {
    final response = await fetchOrdoDay(date);
    if (response.statusCode != 200) return null;
    final value = jsonDecode(response.body);
    final raw = value is Map ? value['tone'] : null;
    final tone = raw is int ? raw : int.tryParse('$raw');
    return tone != null && tone >= 1 && tone <= 8 ? tone : null;
  } catch (_) {
    return null;
  }
}
