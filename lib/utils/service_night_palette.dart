import 'package:flutter/material.dart';

/// Локальная палитра активного читателя. Обычные цвета чтения не изменяются.
class ServiceNightPalette extends ThemeExtension<ServiceNightPalette> {
  const ServiceNightPalette();
  static const background = Color(0xFF000000);
  static const foreground = Color(0xFFD66B62);
  static const accent = Color(0xFFF29586);
  static bool isActive(BuildContext context) =>
      Theme.of(context).extension<ServiceNightPalette>() != null;

  @override
  ServiceNightPalette copyWith() => this;
  @override
  ServiceNightPalette lerp(covariant ServiceNightPalette? other, double t) =>
      this;
}

ThemeData serviceNightTheme(ThemeData base) {
  const scheme = ColorScheme.dark(
    primary: ServiceNightPalette.accent,
    onPrimary: Colors.black,
    secondary: ServiceNightPalette.accent,
    onSecondary: Colors.black,
    primaryContainer: Color(0xFF29100F),
    onPrimaryContainer: ServiceNightPalette.accent,
    secondaryContainer: Color(0xFF29100F),
    onSecondaryContainer: ServiceNightPalette.accent,
    tertiary: ServiceNightPalette.accent,
    onTertiary: Colors.black,
    tertiaryContainer: Color(0xFF29100F),
    onTertiaryContainer: ServiceNightPalette.accent,
    onSurfaceVariant: Color(0xFFB56B62),
    surfaceTint: Colors.transparent,
    surface: Colors.black,
    onSurface: ServiceNightPalette.foreground,
    surfaceContainerHighest: Color(0xFF29100F),
    outline: Color(0xFF87483F),
    error: ServiceNightPalette.accent,
  );
  return base.copyWith(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.black,
    canvasColor: Colors.black,
    cardColor: const Color(0xFF180807),
    textTheme: base.textTheme.apply(
      bodyColor: ServiceNightPalette.foreground,
      displayColor: ServiceNightPalette.foreground,
    ),
    iconTheme: const IconThemeData(color: ServiceNightPalette.accent),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: Colors.black,
      foregroundColor: ServiceNightPalette.accent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        color: ServiceNightPalette.accent,
      ),
      iconTheme: const IconThemeData(color: ServiceNightPalette.accent),
      actionsIconTheme: const IconThemeData(color: ServiceNightPalette.accent),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: ServiceNightPalette.accent,
      selectionColor: Color(0x665E2925),
      selectionHandleColor: ServiceNightPalette.accent,
    ),
    extensions: [...base.extensions.values, const ServiceNightPalette()],
  );
}
