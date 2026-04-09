import 'package:flutter/material.dart';

/// Dağ / av / askeri saha kullanımına uygun koyu tema: yüksek okunabilirlik, tutarlı tipografi.
abstract final class FieldAppTheme {
  static ThemeData dark() {
    const scaffold = Color(0xFF0C100E);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.dark,
      surface: const Color(0xFF151A17),
      surfaceContainerHighest: const Color(0xFF1E2420),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      visualDensity: VisualDensity.standard,
    );

    final titleStyle = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.35,
      color: colorScheme.onSurface,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, colorScheme),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: titleStyle,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 8,
        shadowColor: Colors.black54,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.38),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          const baseFont = TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          );
          if (states.contains(WidgetState.selected)) {
            return baseFont.copyWith(color: colorScheme.primary);
          }
          return baseFont.copyWith(color: colorScheme.onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 26);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.45,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.2),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: colorScheme.surfaceContainerHigh,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.15,
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          height: 1.35,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme t, ColorScheme cs) {
    TextStyle u(
      TextStyle? s, {
      double? height,
      FontWeight? fontWeight,
      double? letterSpacing,
      Color? color,
    }) {
      return (s ?? const TextStyle()).copyWith(
        height: height,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
      );
    }

    return t.copyWith(
      headlineSmall: u(
        t.headlineSmall,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        height: 1.2,
      ),
      titleLarge: u(t.titleLarge, fontWeight: FontWeight.w800, letterSpacing: 0.25, height: 1.22),
      titleMedium: u(t.titleMedium, fontWeight: FontWeight.w700, height: 1.28),
      titleSmall: u(t.titleSmall, fontWeight: FontWeight.w700, height: 1.32),
      bodyLarge: u(t.bodyLarge, height: 1.45, fontWeight: FontWeight.w500),
      bodyMedium: u(t.bodyMedium, height: 1.45),
      bodySmall: u(t.bodySmall, height: 1.38, color: cs.onSurfaceVariant),
      labelLarge: u(t.labelLarge, fontWeight: FontWeight.w800, letterSpacing: 0.5),
    );
  }
}
