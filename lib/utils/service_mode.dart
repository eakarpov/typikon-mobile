import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const serviceModeKey = 'service_mode';
const serviceNightKey = 'service_mode_night';
const servicePagingKey = 'service_mode_paging';
const _channel = MethodChannel('su.typikon.typikon/utils');

/// Настройка общая, удержание экрана — только у видимого читателя.
/// Несколько читателей в стеке не могут снять удержание друг у друга.
class ServiceModeController extends ValueNotifier<bool> {
  ServiceModeController({Future<void> Function(bool)? apply})
    : _apply = apply ?? _platformApply,
      super(false);

  final Future<void> Function(bool) _apply;
  final Set<Object> _readers = {};
  Future<void> _pending = Future.value();
  Future<void>? _loaded;
  bool _requested = false;
  int _revision = 0;
  bool _night = true;
  bool _paging = true;
  bool _active = false;
  bool _notificationScheduled = false;
  bool _disposed = false;

  bool get nightPalette => _night;
  bool get edgePaging => _paging;
  bool get useNightPalette => _active && _night;

  Future<void> setNightPalette(bool enabled) async {
    _revision++;
    _night = enabled;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(
      serviceNightKey,
      enabled,
    );
  }

  Future<void> setEdgePaging(bool enabled) async {
    _revision++;
    _paging = enabled;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(
      servicePagingKey,
      enabled,
    );
  }

  // Появление читателя бывает внутри build. Тему над Navigator обновляем
  // после кадра, чтобы не перестраивать родителя во время сборки ребёнка.
  void _notifyActivity() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else if (!_notificationScheduled) {
      _notificationScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (!_disposed) notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() => _loaded ??= _load();
  Future<void> _load() async {
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (revision == _revision) {
        _night = prefs.getBool(serviceNightKey) ?? true;
        _paging = prefs.getBool(servicePagingKey) ?? true;
        value = prefs.getBool(serviceModeKey) ?? false;
        _sync();
        _notifyActivity();
      }
    } on MissingPluginException {
      // Предпросмотр без платформенного хранилища.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _revision++;
    value = enabled;
    _sync();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(serviceModeKey, enabled);
  }

  void readerVisible(Object reader, bool visible) {
    if (visible) {
      _readers.add(reader);
    } else {
      _readers.remove(reader);
    }
    _sync();
  }

  void _sync() {
    final wanted = value && _readers.isNotEmpty;
    if (wanted != _active) {
      _active = wanted;
      _notifyActivity();
    }
    if (wanted == _requested) return;
    _requested = wanted;
    // Платформенные вызовы выполняются по порядку, в том числе при быстрых
    // переходах и сворачивании сразу после включения.
    _pending = _pending.then((_) => _apply(wanted)).catchError((Object error) {
      debugPrint('Не удалось изменить удержание экрана: $error');
    });
  }

  @visibleForTesting
  Future<void> get settled => _pending;

  static Future<void> _platformApply(bool enabled) async {
    await _channel.invokeMethod<void>('setKeepScreenOn', enabled);
  }
}

final serviceMode = ServiceModeController();
