import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Munshi's visual identity — "modern ledger": warm ink surfaces, a single
/// confident gold accent (money-coded), Bricolage Grotesque display type
/// over Space Grotesk body/numeric type. Supports light + dark.
class MunshiTheme {
  MunshiTheme._();

  // ── Brand ───────────────────────────────────────────────────────────────
  static const Color gold = Color(0xFFE3B23C);
  static const Color goldDeep = Color(0xFFB8842A);
  static const Color onGoldDark = Color(0xFF241B08);

  // ── Dark palette ────────────────────────────────────────────────────────
  static const Color bgDark = Color(0xFF131210);
  static const Color surfaceDark = Color(0xFF1C1A17);
  static const Color surfaceHighDark = Color(0xFF262320);
  static const Color textDark = Color(0xFFF5F1E8);
  static const Color text2Dark = Color(0xFFA8A196);

  // ── Light palette ───────────────────────────────────────────────────────
  static const Color bgLight = Color(0xFFF4EEE1);
  static const Color surfaceLight = Color(0xFFFFFDF8);
  static const Color surfaceHighLight = Color(0xFFEEE6D5);
  static const Color textLight = Color(0xFF221D16);
  static const Color text2Light = Color(0xFF6B6458);
  static const Color goldLight = Color(0xFFB8842A);

  // ── Semantic tokens ───────────────────────────────────────────────────────
  static const Color positive = Color(0xFF6BBF8A); // income (dark)
  static const Color positiveLight = Color(0xFF2E8B63); // income (light)
  static const Color negative = Color(0xFFE0574A); // expense / over-budget (dark)
  static const Color negativeLight = Color(0xFFC4402F); // (light)
  static const Color warn = Color(0xFFE8A13C); // budget ≥80% used
  static const Color transferNeutral = Color(0xFF8A94A6);

  // ── Backwards-compatible aliases ─────────────────────────────────────────
  // The screens were written against the earlier teal palette; these keep them
  // compiling and re-point them at the new gold/ink tokens automatically.
  static const Color accent = gold;
  static const Color accentDeep = goldDeep;
  static const Color background = bgDark;
  static const Color surface = surfaceDark;
  static const Color surfaceHigh = surfaceHighDark;

  /// Hero-card gradient in the gold/ink identity — warm ink so white text and
  /// gold accents both read cleanly (replaces the old teal gradient).
  static const List<Color> heroGradient = [Color(0xFF2A2016), Color(0xFF14110D)];

  static TextTheme _textTheme(Color text, Color text2) {
    final display = GoogleFonts.bricolageGrotesqueTextTheme();
    final body = GoogleFonts.spaceGroteskTextTheme();
    return body.copyWith(
      displayLarge: display.displayLarge
          ?.copyWith(color: text, fontWeight: FontWeight.w800),
      displayMedium: display.displayMedium
          ?.copyWith(color: text, fontWeight: FontWeight.w800),
      displaySmall: display.displaySmall
          ?.copyWith(color: text, fontWeight: FontWeight.w800),
      headlineLarge: display.headlineLarge
          ?.copyWith(color: text, fontWeight: FontWeight.w700),
      headlineMedium: display.headlineMedium
          ?.copyWith(color: text, fontWeight: FontWeight.w700),
      headlineSmall: display.headlineSmall
          ?.copyWith(color: text, fontWeight: FontWeight.w800),
      titleLarge: body.titleLarge?.copyWith(color: text, fontWeight: FontWeight.w700),
      titleMedium:
          body.titleMedium?.copyWith(color: text, fontWeight: FontWeight.w700),
      titleSmall:
          body.titleSmall?.copyWith(color: text, fontWeight: FontWeight.w600),
      bodyLarge: body.bodyLarge?.copyWith(color: text),
      bodyMedium: body.bodyMedium?.copyWith(color: text),
      bodySmall: body.bodySmall?.copyWith(color: text2),
      labelLarge:
          body.labelLarge?.copyWith(color: text2, fontWeight: FontWeight.w600),
      labelMedium:
          body.labelMedium?.copyWith(color: text2, fontWeight: FontWeight.w600),
      labelSmall:
          body.labelSmall?.copyWith(color: text2, fontWeight: FontWeight.w600),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: goldDeep,
      brightness: Brightness.dark,
    ).copyWith(
      primary: gold,
      surface: surfaceDark,
      surfaceContainerHighest: surfaceHighDark,
      error: negative,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bgDark,
    );

    return base.copyWith(
      textTheme: _textTheme(textDark, text2Dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDark,
        indicatorColor: gold.withValues(alpha: 0.22),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? gold : Colors.white54);
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: onGoldDark,
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: goldLight,
      brightness: Brightness.light,
    ).copyWith(
      primary: goldLight,
      surface: surfaceLight,
      surfaceContainerHighest: surfaceHighLight,
      error: negativeLight,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: bgLight,
    );

    return base.copyWith(
      textTheme: _textTheme(textLight, text2Light),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceLight,
        indicatorColor: goldLight.withValues(alpha: 0.22),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? goldLight : Colors.black38);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: goldLight,
        foregroundColor: surfaceLight,
      ),
    );
  }
}
