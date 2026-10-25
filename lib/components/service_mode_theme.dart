import 'package:flutter/material.dart';
import '../utils/service_mode.dart';
import '../utils/service_night_palette.dart';

/// Над Navigator, чтобы ночные цвета получили и шапка, и меню выделения.
class ServiceModeTheme extends StatelessWidget {
  const ServiceModeTheme({super.key, required this.child, this.controller});
  final Widget child;
  final ServiceModeController? controller;

  @override
  Widget build(BuildContext context) {
    final mode = controller ?? serviceMode;
    return AnimatedBuilder(
      animation: mode,
      child: child,
      builder: (context, child) => Theme(
        data: mode.useNightPalette
            ? serviceNightTheme(Theme.of(context))
            : Theme.of(context),
        child: child!,
      ),
    );
  }
}
