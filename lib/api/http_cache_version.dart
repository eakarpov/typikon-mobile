import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'client.dart';
import 'constants.dart';

class HttpCacheVersionState {
  final String? server;
  final int epoch;
  const HttpCacheVersionState({this.server, this.epoch = 0});
}

abstract class HttpCacheVersionStorage {
  Future<HttpCacheVersionState> read();
  Future<void> write(HttpCacheVersionState state);
}

class PreferencesHttpCacheVersionStorage implements HttpCacheVersionStorage {
  static const key = 'http_cache_version_state';

  @override
  Future<HttpCacheVersionState> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return const HttpCacheVersionState();
    final value = jsonDecode(raw);
    return HttpCacheVersionState(
      server: value['server'] is String ? value['server'] : null,
      epoch: value['epoch'] is int ? value['epoch'] : 0,
    );
  }

  @override
  Future<void> write(HttpCacheVersionState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({'server': state.server, 'epoch': state.epoch}),
    );
  }
}

/// Метаданные запрашиваются напрямую, без HTTP-кэша, API-ключа и Cookie.
/// Старый сервер узнаётся по health/BUILD_ID до появления нового endpoint.
Future<String?> fetchHttpCacheServerVersion({http.Client? client}) async {
  final transport = client ?? apiClient;
  var response = await transport
      .get(
        Uri.parse('$apiBaseUrl/api/cache-version'),
        headers: {'Cache-Control': 'no-cache'},
      )
      .timeout(const Duration(seconds: 2));
  var field = 'version';
  var prefix = 'server';
  if (response.statusCode == 404) {
    response = await transport
        .get(
          Uri.parse('$apiBaseUrl/api/health'),
          headers: {'Cache-Control': 'no-cache'},
        )
        .timeout(const Duration(seconds: 2));
    field = 'buildId';
    prefix = 'build';
  }
  if (response.statusCode != 200) return null;
  final value = jsonDecode(response.body);
  final token = value is Map ? value[field] : null;
  if (token is! String ||
      !RegExp(r'^[a-zA-Z0-9._:-]{1,160}$').hasMatch(token)) {
    return null;
  }
  return '$prefix:$token';
}

/// Поколение публичного HTTP-кэша. Личные хранилища сюда не входят.
class HttpCacheVersions {
  static const checkInterval = Duration(minutes: 5);
  final String appBuild;
  final HttpCacheVersionStorage storage;
  final Future<String?> Function() fetchServerVersion;
  final DateTime Function() now;
  final _changes = StreamController<void>.broadcast();
  HttpCacheVersionState _state = const HttpCacheVersionState();
  Future<void>? _initializing;
  Future<bool>? _checking;
  DateTime? _lastCheck;
  bool _checked = false;
  bool serverReachable = false;

  HttpCacheVersions({
    this.appBuild = appVersion,
    HttpCacheVersionStorage? storage,
    Future<String?> Function()? fetchServerVersion,
    DateTime Function()? now,
  }) : storage = storage ?? PreferencesHttpCacheVersionStorage(),
       fetchServerVersion = fetchServerVersion ?? fetchHttpCacheServerVersion,
       now = now ?? DateTime.now;

  Stream<void> get changes => _changes.stream;
  String get generation =>
      'v1|$appBuild|${_state.server ?? "unknown"}|${_state.epoch}';

  Future<void> _initialize() => _initializing ??= () async {
    try {
      _state = await storage.read();
    } catch (_) {
      /* Кэш необязателен. */
    }
  }();

  Future<bool> check({bool force = false}) async {
    await _initialize();
    if (_checking != null) return _checking!;
    final last = _lastCheck;
    if (!force && last != null && now().difference(last) < checkInterval) {
      return false;
    }
    final pending = _check();
    _checking = pending;
    try {
      return await pending;
    } finally {
      _checking = null;
    }
  }

  Future<bool> _check() async {
    _lastCheck = now();
    final alreadyChecked = _checked;
    _checked = true;
    try {
      final server = await fetchServerVersion();
      if (server == null || server.isEmpty) {
        serverReachable = false;
        return false;
      }
      serverReachable = true;
      if (server == _state.server) return false;
      _state = HttpCacheVersionState(server: server, epoch: _state.epoch);
      try {
        await storage.write(_state);
      } catch (_) {
        /* Офлайн-кэш best effort. */
      }
      // При старте запросы ещё ждут проверки и сами получат новое поколение.
      if (alreadyChecked) _changes.add(null);
      return true;
    } catch (_) {
      serverReachable = false;
      return false;
    }
  }

  Future<void> invalidateLocally() async {
    await _initialize();
    _state = HttpCacheVersionState(
      server: _state.server,
      epoch: _state.epoch + 1,
    );
    try {
      await storage.write(_state);
    } catch (_) {
      /* Не препятствует очистке. */
    }
  }

  Future<void> dispose() => _changes.close();
}

final httpCacheVersions = HttpCacheVersions();
