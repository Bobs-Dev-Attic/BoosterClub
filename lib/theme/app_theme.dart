import 'package:flutter/material.dart';

/// Central Material 3 theme. Walter Johnson Wildcats colors: kelly green + white.
///
/// Typography intentionally uses Flutter's built-in default font (bundled with
/// the app) rather than a web-fetched font. Runtime font fetching (e.g. Google
/// Fonts) can leave text blank on Flutter web when the download is blocked by a
/// VPN, content blocker, or restrictive network — so we avoid depending on it.
class AppTheme {
  /// Primary brand color — Walter Johnson kelly green.
  static const Color green = Color(0xFF00843D);
  static const Color greenDark = Color(0xFF00602A);

  /// Backwards-compatible aliases (the app was seeded with navy/gold names).
  static const Color navy = green;
  static const Color gold = greenDark;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      primary: green,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    );
    return base.copyWith(
      // Use the default (bundled) text theme — no runtime font fetch.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

/// Headline style helper for hero sections. Uses the bundled default font so
/// headings always render, even when web font fetching is blocked.
TextStyle displayFont(BuildContext context,
        {double size = 32, FontWeight weight = FontWeight.w700, Color? color}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
