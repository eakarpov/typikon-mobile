import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../store/models/models.dart';
import 'service_reading_scope.dart';

/// Размер текста щипком — на время экрана.
///
/// **Не настройка, а жест.** Кто развёл пальцы над мелкой сноской или над
/// титлом, хочет разглядеть это место, а не поменять кегль всех чтений; кегль
/// меняется в настройках. Поэтому масштаб живёт в состоянии экрана и уходит
/// вместе с ним.
///
/// **Слушаем касания, а не спорим за жест.** `GestureDetector` со щипком
/// вступает в спор с прокруткой и выигрывает его на одном пальце: масштаб в
/// единицу — тоже масштаб, и страница переставала бы листаться. `Listener` в
/// споре не участвует: прокрутка и выделение слова остаются как были, а два
/// пальца мы считаем сами.
class PinchZoom extends StatefulWidget {
  const PinchZoom({super.key, required this.child});

  final Widget child;

  @override
  State<PinchZoom> createState() => _PinchZoomState();
}

class _PinchZoomState extends State<PinchZoom> {
  final Map<int, Offset> _pointers = {};
  double _scale = 1.0;
  double? _startDistance;
  double _startScale = 1.0;

  /// Подпись с кеглем видна, пока пальцы на стекле, и чуть после.
  bool _showSize = false;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  double get _distance {
    final points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  void _down(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _startDistance = _distance;
      _startScale = _scale;
      _hide?.cancel();
      setState(() => _showSize = true);
    }
  }

  void _move(PointerMoveEvent event, int fontSize) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final start = _startDistance;
    if (_pointers.length != 2 || start == null || start < 1.0) return;

    // Кегль — в пределах, что и у ползунка настроек: мельче не прочесть,
    // крупнее не помещается строка.
    final scale = (_startScale * _distance / start).clamp(
      minFontSize / fontSize,
      maxFontSize / fontSize,
    );
    if ((scale - _scale).abs() > 0.01) setState(() => _scale = scale);
  }

  void _up(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2 && _startDistance != null) {
      _startDistance = null;
      _hide?.cancel();
      _hide = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showSize = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = StoreProvider.of<AppState>(
      context,
    ).state.settings.fontSize;
    final media = MediaQuery.of(context);

    return ServiceReadingScope(
      child: Listener(
        onPointerDown: _down,
        onPointerMove: (event) => _move(event, fontSize),
        onPointerUp: _up,
        onPointerCancel: _up,
        child: Stack(
          children: [
            ReadingZoom(
              scale: _scale,
              // `Text` берёт масштаб из `MediaQuery` — туда он и кладётся, поверх
              // системного, а не вместо него.
              child: MediaQuery(
                data: media.copyWith(
                  textScaler: _Zoomed(media.textScaler, _scale),
                ),
                child: widget.child,
              ),
            ),
            Positioned(
              top: 12.0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _showSize ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: Chip(
                      label: Text("Кегль ${(fontSize * _scale).round()}"),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Масштаб щипка для тех, кто рисует голым `RichText`.
///
/// `RichText`, в отличие от `Text`, масштаба из `MediaQuery` не берёт — и
/// системного тоже, так что текст чтений его и прежде не слушал. Отдаём им
/// один масштаб щипка: системный там не действовал и теперь не начнёт.
class ReadingZoom extends InheritedWidget {
  const ReadingZoom({super.key, required this.scale, required super.child});

  final double scale;

  static TextScaler scalerOf(BuildContext context) {
    final zoom = context.dependOnInheritedWidgetOfExactType<ReadingZoom>();
    return zoom == null || zoom.scale == 1.0
        ? TextScaler.noScaling
        : TextScaler.linear(zoom.scale);
  }

  @override
  bool updateShouldNotify(ReadingZoom oldWidget) => scale != oldWidget.scale;
}

/// Системный масштаб, умноженный на щипок.
class _Zoomed extends TextScaler {
  const _Zoomed(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _Zoomed && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
