import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import '../utils/route_observer.dart';
import '../utils/service_mode.dart';

class ServiceReadingScope extends StatefulWidget {
  const ServiceReadingScope({super.key, required this.child, this.controller});
  final Widget child;
  final ServiceModeController? controller;
  @override
  State<ServiceReadingScope> createState() => _ServiceReadingScopeState();
}

class _ServiceReadingScopeState extends State<ServiceReadingScope>
    with WidgetsBindingObserver, RouteAware {
  PageRoute<dynamic>? _route;
  bool _visible = true;
  bool _foreground = true;
  ScrollableState? _scrollable;
  final Set<int> _pointers = {};
  int? _tapPointer;
  Offset? _tapStart;
  Duration _tapTime = Duration.zero;

  void _rememberScroll(BuildContext? context, Axis axis, int depth) {
    if (axis == Axis.vertical && depth == 0 && context != null) {
      _scrollable = Scrollable.maybeOf(context);
    }
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (!_controller.value ||
        !_controller.edgePaging ||
        _pointers.length != 1 ||
        event.buttons != kPrimaryButton) {
      _tapPointer = null;
      return;
    }
    final hits = HitTestResult();
    GestureBinding.instance.hitTestInView(hits, event.position, event.viewId);
    for (final hit in hits.path) {
      final target = hit.target;
      if ((target is TextSpan && target.recognizer != null) ||
          (target is RenderSemanticsAnnotations &&
              (target.properties.button == true ||
                  target.properties.link == true))) {
        _tapPointer = null;
        return;
      }
    }
    _tapPointer = event.pointer;
    _tapStart = event.localPosition;
    _tapTime = event.timeStamp;
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_tapPointer == event.pointer &&
        _tapStart != null &&
        (event.localPosition - _tapStart!).distance > 12) {
      _tapPointer = null;
    }
  }

  void _pointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    final start = _tapStart;
    final isTap =
        _tapPointer == event.pointer &&
        start != null &&
        event.timeStamp - _tapTime < const Duration(milliseconds: 300);
    _tapPointer = null;
    if (!isTap || !_controller.value || !_controller.edgePaging) return;
    final size = context.size;
    if (size == null || start.dy < 24 || start.dy > size.height - 80) return;
    final edge = (size.width * .1).clamp(24.0, 48.0);
    if (start.dx <= edge) {
      _turnPage(-1);
    } else if (start.dx >= size.width - edge) {
      _turnPage(1);
    }
  }

  void _turnPage(int direction) {
    final scrollable = _scrollable;
    if (scrollable == null || !scrollable.mounted) return;
    final position = scrollable.position;
    if (!position.hasContentDimensions) return;
    final target =
        (position.pixels + direction * position.viewportDimension * .85).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    unawaited(
      position.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      ),
    );
  }

  ServiceModeController get _controller => widget.controller ?? serviceMode;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      routeObserver.unsubscribe(this);
      _route = route;
      _visible = route.isCurrent;
      routeObserver.subscribe(this, route);
    }
    _sync();
  }

  void _sync() => _controller.readerVisible(this, _visible && _foreground);
  @override
  void didPush() {
    _visible = true;
    _sync();
  }

  @override
  void didPop() {
    _visible = false;
    _sync();
  }

  @override
  void didPushNext() {
    _visible = false;
    _sync();
  }

  @override
  void didPopNext() {
    _visible = true;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller.readerVisible(this, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Listener(
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerUp,
      onPointerCancel: (event) {
        _pointers.remove(event.pointer);
        _tapPointer = null;
      },
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notice) {
          _rememberScroll(notice.context, notice.metrics.axis, notice.depth);
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notice) {
            _rememberScroll(notice.context, notice.metrics.axis, notice.depth);
            return false;
          },
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  bottom: _controller.value
                      ? 72 + MediaQuery.paddingOf(context).bottom
                      : 0,
                ),
                child: widget.child,
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: SafeArea(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _controller,
                    builder: (context, enabled, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (enabled && _controller.edgePaging)
                          IconButton.filledTonal(
                            tooltip: 'Предыдущий экран',
                            onPressed: () => _turnPage(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                        if (enabled)
                          IconButton.filledTonal(
                            tooltip: 'Ночная палитра',
                            isSelected: _controller.nightPalette,
                            icon: const Icon(Icons.dark_mode_outlined),
                            selectedIcon: const Icon(Icons.dark_mode),
                            onPressed: () => _controller.setNightPalette(
                              !_controller.nightPalette,
                            ),
                          ),
                        IconButton.filledTonal(
                          tooltip: enabled
                              ? 'На службе: экран не гаснет'
                              : 'Включить режим «На службе»',
                          isSelected: enabled,
                          icon: const Icon(Icons.light_mode_outlined),
                          selectedIcon: const Icon(Icons.light_mode),
                          onPressed: () => _controller.setEnabled(!enabled),
                        ),
                        if (enabled && _controller.edgePaging)
                          IconButton.filledTonal(
                            tooltip: 'Следующий экран',
                            onPressed: () => _turnPage(1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
