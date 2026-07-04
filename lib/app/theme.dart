import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Munshi's visual identity: professional fintech dark theme.
/// Near-black neutral surfaces, a single confident deep-teal accent
/// (money-coded), high-contrast Inter typography, generous whitespace.
class MunshiTheme {
  MunshiTheme._();

  // Core palette.
  static const Color accent = Color(0xFF2DD4BF); // bright teal highlight
  static const Color accentDeep = Color(0xFF0D9488); // deep teal
  static const Color background = Color(0xFF0B0F10); // near-black, slight green
  static const Color surface = Color(0xFF14191B);
  static const Color surfaceHigh = Color(0xFF1C2325);
  static const Color positive = Color(0xFF34D399); // income green
  static const Color negative = Color(0xFFF87171); // expense red

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accentDeep,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      surface: surface,
      surfaceContainerHighest: surfaceHigh,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accentDeep.withValues(alpha: 0.28),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accent : Colors.white54,
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Color(0xFF04120F),
      ),
    );
  }
}
