import 'dart:convert';

import 'package:archive/archive.dart';

import '../dto/ordo_services.dart';

/// Читатель .ordo 1.0 (одна служба) и 1.1 (день). Не извлекает файлы на диск.
class OrdoPackage {
  final String? date;
  final List<Map<String, dynamic>> _services;
  OrdoServices get reading => OrdoServices.fromJson({'services': _services});

  const OrdoPackage._(this.date, this._services);

  /// Свободный пакет везёт Писание ссылками. Сбой резолвера сохраняет
  /// ссылку и явную помету; остальные тексты доступны и без сети.
  Future<void> resolveScripture(
    Future<String?> Function(String) resolve,
  ) async {
    final items = <Map>[];
    void walk(dynamic steps) {
      if (steps is! List) return;
      for (final step in steps.whereType<Map>()) {
        for (final item
            in (step['items'] as List? ?? const []).whereType<Map>()) {
          if (item['is_nested_step'] == true) walk([item['step']]);
          if (item['absent'] == 'external' &&
              item['address'] is String &&
              (item['address'] as String).startsWith('bible:')) {
            items.add(item);
          }
        }
      }
    }

    for (final service in _services) {
      walk(service['steps']);
    }
    final refs = items.map((i) => i['address'] as String).toSet().toList();
    final texts = <String, String>{};
    // Ограничиваем одновременно открытые запросы, главы резолвер кэширует.
    for (var i = 0; i < refs.length; i += 4) {
      await Future.wait(
        refs.skip(i).take(4).map((ref) async {
          try {
            final text = await resolve(ref);
            if (text != null && text.trim().isNotEmpty) texts[ref] = text;
          } catch (_) {
            /* Оставляем адрес и причину отсутствия тела. */
          }
        }),
      );
    }
    for (final item in items) {
      if (texts.containsKey(item['address'])) {
        item['text'] = texts[item['address']];
      }
    }
  }

  static const maxBytes = 64 * 1024 * 1024;

  factory OrdoPackage.decode(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Пакет .ordo слишком большой');
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    final parts = <String, dynamic>{};
    var size = 0;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      size += file.size;
      if (size > maxBytes || archive.files.length > 4096) {
        throw const FormatException('Пакет .ordo слишком большой');
      }
      if (!file.name.endsWith('.json') && !file.name.endsWith('.jsonl')) {
        continue;
      }
      final text = utf8.decode(file.content);
      parts[file.name] = file.name.endsWith('.jsonl')
          ? const LineSplitter()
                .convert(text)
                .where((s) => s.trim().isNotEmpty)
                .map((s) => jsonDecode(s))
                .toList()
          : jsonDecode(text);
    }
    final manifest = parts['manifest.json'];
    if (manifest is! Map ||
        manifest['format'] != 'posledovanie' ||
        !'${manifest['spec_version']}'.startsWith('1.')) {
      throw const FormatException('Неизвестный формат пакета .ordo');
    }
    final day = parts['ordo.json'];
    if (day is! Map) throw const FormatException('В пакете нет ordo.json');
    final scope = manifest['scope'] is Map ? manifest['scope'] as Map : {};
    final addresses = parts['addresses.json'];
    final lines = addresses is Map && addresses['lines'] is List
        ? (addresses['lines'] as List).whereType<Map>().toList()
        : <Map>[];

    Map<String, dynamic> stitch(Map part, String? key) {
      final result = Map<String, dynamic>.from(part);
      final steps = result['steps'];
      if (steps is! List) {
        if (result['error'] != null) return result;
        throw const FormatException('В службе нет шагов последования');
      }
      for (final entry in lines.where(
        (e) => key == null || e['service'] == key,
      )) {
        final i = entry['step'];
        final j = entry['item'];
        if (i is! int || i < 0 || i >= steps.length || steps[i] is! Map) {
          throw const FormatException('Повреждён адрес шага в .ordo');
        }
        final items = steps[i]['items'];
        if (items is! List ||
            j is! int ||
            j < 0 ||
            j >= items.length ||
            items[j] is! Map) {
          throw const FormatException('Повреждён адрес текста в .ordo');
        }
        final item = items[j] as Map;
        final body = entry['body'];
        if (body is! Map) {
          throw const FormatException('Нет ссылки на тело текста');
        }
        final absent = body['absent'];
        if (body['in'] != null) {
          final rows = parts[body['in']];
          final line = body['line'];
          if (rows is! List ||
              line is! int ||
              line < 0 ||
              line >= rows.length ||
              rows[line] is! Map ||
              rows[line]['text'] is! String) {
            throw const FormatException(
              'Повреждена ссылка на тело текста в .ordo',
            );
          }
          item['text'] = rows[line]['text'];
        } else if (absent != 'unset' || item['text'] == null) {
          item.remove('text');
        }
        if (absent != null) item['absent'] = absent;
        for (final field in ['address', 'edition', 'language', 'cite']) {
          if (entry[field] != null) item.putIfAbsent(field, () => entry[field]);
        }
      }
      return result;
    }

    final serviceFiles = parts.keys
        .where((p) => p.startsWith('services/') && p.endsWith('.json'))
        .toList();
    final services = <Map<String, dynamic>>[];
    if (scope['services'] is List || serviceFiles.isNotEmpty) {
      final order = scope['services'] is List
          ? scope['services'] as List
          : serviceFiles.map((p) => p.substring(9, p.length - 5)).toList();
      for (final key in order) {
        final part = parts['services/$key.json'];
        if (key is! String || part is! Map) {
          throw const FormatException(
            'В пакете отсутствует служба из манифеста',
          );
        }
        services.add(stitch(part, key));
      }
    } else {
      services.add(stitch(day, null));
    }
    return OrdoPackage._(scope['date'] as String?, services);
  }
}
