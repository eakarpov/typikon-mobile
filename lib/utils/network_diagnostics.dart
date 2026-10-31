import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../api/cached_fetch.dart';
import '../api/client.dart';
import '../api/constants.dart';
import '../api/http_cache_version.dart';
import '../api/v2/api_key.dart';
import '../dto/library.dart';
export 'diagnostic_flags.dart';
import 'network_error_detail.dart';

Future<String> diagnoseAndroidHttps() async {
  final report = await const MethodChannel('su.typikon.typikon/utils')
      .invokeMapMethod<String, dynamic>('diagnoseHttps')
      .timeout(const Duration(seconds: 20));
  if (report == null) {
    throw const FormatException('Android не вернул результат');
  }
  if (report['error'] != null) {
    throw StateError(report['error'].toString());
  }
  if (report['status'] != 200) {
    throw HttpException('Android HTTP ${report['status']}');
  }
  return 'OK: Android HTTP 200, ${report['cipher']}';
}

class _DiagnosticStorage implements HttpCacheVersionStorage {
  HttpCacheVersionState value = const HttpCacheVersionState();
  @override
  Future<HttpCacheVersionState> read() async => value;
  @override
  Future<void> write(HttpCacheVersionState state) async => value = state;
}

/// Exercises the production cache on disk, with its own key and in-memory
/// version metadata. Does not clear or invalidate the user's cache generation.
Future<List<String>> testDiagnosticCache() async {
  final key = 'network-diagnostic:${DateTime.now().microsecondsSinceEpoch}';
  var server = 'test-1';
  final versions = HttpCacheVersions(
    appBuild: 'network-self-test',
    storage: _DiagnosticStorage(),
    fetchServerVersion: () async => server,
  );
  final lines = <String>[];
  var fetches = 0;
  Future<http.Response> fresh(String value) async {
    fetches++;
    return http.Response(jsonEncode({'value': value}), 200);
  }

  void verify(bool ok, String label) {
    if (!ok) throw StateError('FAIL: $label');
    lines.add('OK: $label');
  }

  try {
    await versions.check();
    final first = await cachedFetch(
      key,
      () => fresh('one'),
      versions: versions,
    );
    verify(first.body.contains('one'), 'запись нового ответа');
    final second = await cachedFetch(
      key,
      () => fresh('unexpected'),
      versions: versions,
    );
    verify(
      second.body == first.body && fetches == 1,
      'повторное чтение с диска без сети',
    );
    server = 'test-2';
    await versions.check(force: true);
    final updated = await cachedFetch(
      key,
      () => fresh('two'),
      versions: versions,
    );
    verify(
      updated.body.contains('two') && fetches == 2,
      'обновление после смены версии сервера',
    );
    server = 'test-3';
    await versions.check(force: true);
    final offline = await cachedFetch(
      key,
      () async => throw const SocketException('simulated offline'),
      versions: versions,
    );
    verify(
      offline.body == updated.body,
      'сохранённый ответ при сетевой ошибке',
    );
    final unavailable = await cachedFetch(
      key,
      () async => http.Response('unavailable', 503),
      versions: versions,
    );
    verify(unavailable.body == updated.body, 'сохранённый ответ при HTTP 503');
    return lines;
  } finally {
    await versions.dispose();
    await removeDiagnosticCacheEntry(key);
  }
}

/// Reports only technical information. No cookies, keys, account data, cache
/// bodies, names from the commemoration book or automatic uploads.
Future<void> runNetworkDiagnostics(void Function(String) emit) async {
  emit(
    'Typikon $appVersion · NETWORK_DIAGNOSTICS v2\n${DateTime.now().toIso8601String()}',
  );
  emit(
    'Система: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
  );

  Future<void> step(String title, Future<String> Function() work) async {
    emit('\n▶ $title');
    final clock = Stopwatch()..start();
    try {
      final result = await work().timeout(const Duration(seconds: 25));
      emit('$result\nВремя: ${clock.elapsedMilliseconds} мс');
    } catch (error) {
      emit(
        'FAIL: ${describeNetworkError(error)}\nВремя: ${clock.elapsedMilliseconds} мс',
      );
    }
  }

  await step('Устройство', () async {
    if (!Platform.isAndroid) return Platform.operatingSystem;
    final device = await DeviceInfoPlugin().androidInfo;
    return '${device.manufacturer} ${device.model}; Android ${device.version.release}; SDK ${device.version.sdkInt}';
  });
  await step('DNS $siteHostFull', () async {
    final addresses = await InternetAddress.lookup(
      siteHostFull,
    ).timeout(const Duration(seconds: 8));
    return addresses.map((a) => '${a.type.name}: ${a.address}').join('\n');
  });
  await step('TCP $siteHostFull:443 (Dart)', () async {
    final socket = await Socket.connect(
      siteHostFull,
      443,
      timeout: const Duration(seconds: 8),
    );
    try {
      return 'OK: TCP-соединение с ${socket.remoteAddress.address}:443';
    } finally {
      socket.destroy();
    }
  });
  await step('TLS поверх TCP (Dart)', () async {
    final tcp = await Socket.connect(
      siteHostFull,
      443,
      timeout: const Duration(seconds: 8),
    );
    try {
      emit('TCP установлен; начинаем TLS');
      final socket = await SecureSocket.secure(
        tcp,
        host: siteHostFull,
      ).timeout(const Duration(seconds: 10));
      final certificate = socket.peerCertificate;
      try {
        return 'OK: защищённое соединение\nIssuer: ${certificate?.issuer}\nСрок: ${certificate?.startValidity} — ${certificate?.endValidity}';
      } finally {
        socket.destroy();
      }
    } finally {
      tcp.destroy();
    }
  });
  if (Platform.isAndroid) {
    await step(
      'HTTPS через системный Android (без кэша)',
      diagnoseAndroidHttps,
    );
  }

  Future<String> request(
    http.Client client,
    String path, {
    Map<String, String>? headers,
  }) async {
    final response = await client
        .get(Uri.parse('$apiBaseUrl$path'), headers: headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}: $path');
    }
    final content = jsonDecode(response.body);
    if (content is! Map && content is! List) {
      throw const FormatException('Ответ не является JSON-объектом/списком');
    }
    if (path == '/api/health' &&
        (content is! Map || content['status'] != 'ready')) {
      throw const FormatException('Сервер не ready');
    }
    return 'OK: HTTP ${response.statusCode}, ${response.bodyBytes.length} байт, JSON ${content.runtimeType}';
  }

  await step(
    'HTTPS напрямую, общий клиент (без кэша)',
    () => request(apiClient, '/api/health'),
  );
  await step('HTTPS напрямую, новое соединение (без кэша)', () async {
    final client = createApiClient(http.Client());
    try {
      return await request(client, '/api/health');
    } finally {
      client.close();
    }
  });
  await step('Проверка версии кэша (штатный таймаут 2 с)', () async {
    final version = await fetchHttpCacheServerVersion();
    if (version == null) {
      throw const FormatException('Метаданные версии не приняты');
    }
    return 'OK: $version';
  });
  await step(
    'Метаданные кэша напрямую (таймаут 12 с)',
    () => request(apiClient, '/api/cache-version'),
  );
  await step('Состояние общего кэша', () async {
    await httpCacheVersions.check(force: true);
    return 'serverReachable: ${httpCacheVersions.serverReachable}\ngeneration: ${httpCacheVersions.generation}';
  });
  await step(
    'Существующий кэш библиотеки (только чтение)',
    () async => jsonEncode(await inspectHttpCacheEntry('library')),
  );
  await step(
    'API библиотеки без ключа и без кэша',
    () => request(apiClient, '/api/v2/books?limit=200'),
  );
  await step('API библиотеки с ключом приложения, без кэша', () async {
    if (apiKeyHeaders().isEmpty) {
      return 'SKIP: ключ приложения отсутствует или ранее отклонён';
    }
    return request(
      apiClient,
      '/api/v2/books?limit=200',
      headers: apiKeyHeaders(),
    );
  });
  await step('Библиотека через штатный механизм кэша', () async {
    final response = await cachedFetch(
      'library',
      () => apiClient
          .get(
            Uri.parse('$apiBaseUrl/api/v2/books?limit=200'),
            headers: apiKeyHeaders(),
          )
          .timeout(apiTimeout),
      ttl: const Duration(hours: 24),
      versions: httpCacheVersions,
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200 || (decoded is! Map && decoded is! List)) {
      throw HttpException(
        'HTTP ${response.statusCode}, некорректный ответ библиотеки',
      );
    }
    final books = BookList.fromJson(decoded);
    return 'OK: HTTP 200, ${response.bodyBytes.length} байт, книг: ${books.list.length}';
  });
  await step(
    'Самопроверка кэша на временной записи',
    () async => (await testDiagnosticCache()).join('\n'),
  );
  emit(
    '\nПроверка завершена. FAIL прямого HTTPS/API означает сбой вне кэша. '
    'Прямой API работает, но штатный путь нет — нужно исследовать кэш/загрузку. '
    'Успешная самопроверка не исключает повреждение отдельной старой записи.',
  );
}
