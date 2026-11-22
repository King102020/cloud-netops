import 'package:flutter/material.dart';

/// One Material 3 theme, light and dark (STANDARDS §6). The seed is a deep
/// teal; status colours are checked for contrast on both brightnesses.
abstract final class AppTheme {
  static const _seed = Color(0xFF00696B);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      // 48dp minimum touch targets everywhere (WCAG 2.2 AA, Material).
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}

/// Semantic status colours derived from the scheme.
extension StatusColors on ColorScheme {
  Color get ok => brightness == Brightness.light
      ? const Color(0xFF1B6C2F)
      : const Color(0xFF8BD89A);
  Color get warn => brightness == Brightness.light
      ? const Color(0xFF8A5100)
      : const Color(0xFFFFB866);
  Color get bad => error;
}
