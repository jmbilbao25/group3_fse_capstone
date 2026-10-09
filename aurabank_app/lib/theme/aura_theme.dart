import 'package:flutter/material.dart';

/// Aura Bank design tokens.
///
/// Four brand colours carry the whole system: sky, mint, ink and paper. The
/// aurora is the only place the two light hues blend; everywhere else they are
/// used flat. Member names predate the palette and are kept so every screen
/// moved onto the new tokens without a rename.
class AuraColors {
  // Brand
  static const Color sky = Color(0xFF97CFF3);
  static const Color mint = Color(0xFFA7E8D1);
  static const Color ink = Color(0xFF10171C);
  static const Color paper = Color(0xFFF7F7F7);
  static const Color periwinkle = Color(0xFFBEC6F7);
  static const Color ember = Color(0xFFF2A25C);

  // Roles. Ink is the action colour; mint and sky stay as fills because
  // neither holds 4.5:1 as text on white.
  static const Color primary = ink;
  static const Color primaryDark = Color(0xFF0A0F13);
  static const Color accent = Color(0xFF1C6E5A); // mint, deepened for text on white
  static const Color accentVibrant = Color(0xFF2F78A8); // sky, deepened for text on white
  static const Color accentLight = mint;

  // Tints
  static const Color tintPurple = Color(0xFFE6F6EF); // mint wash
  static const Color borderPurple = Color(0xFFC9EBDD);
  static const Color bgLavender = Color(0xFFEFF6FB); // sky wash
  static const Color borderLavender = Color(0xFFDDEAF3);

  // Surfaces
  static const Color canvas = paper;
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFEAECEE);
  static const Color divider = Color(0xFFE6E8EA);
  static const Color inkRaised = Color(0xFF1A2329);
  static const Color inkLine = Color(0xFF26313A);

  // Text
  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF47525C);
  static const Color textMuted = Color(0xFF7D8892);

  // Money
  static const Color creditGreen = Color(0xFF17805F);
  static const Color creditGreenBg = Color(0xFFE4F5EE);
  static const Color debitRed = Color(0xFFC8423B);
  static const Color debitRedBg = Color(0xFFFBE9E7);
  static const Color amberWarning = Color(0xFFB7681E);

  static const LinearGradient balanceHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10171C), Color(0xFF15232A), Color(0xFF173039)],
  );

  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sky, mint],
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: ink.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: ink.withValues(alpha: 0.22),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];
}

/// Durations and curves. One deceleration curve for arrivals, a shorter run
/// for exits, and nothing that bounces.
class AuraMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 560);
  static const Curve emphasized = Cubic(0.16, 1, 0.3, 1);
  static const Curve standard = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration resolve(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

class AuraTheme {
  static const String fontFamily = 'Onest';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AuraColors.mint,
      primary: AuraColors.ink,
      onPrimary: Colors.white,
      secondary: AuraColors.mint,
      onSecondary: AuraColors.ink,
      tertiary: AuraColors.sky,
      surface: Colors.white,
      onSurface: AuraColors.ink,
      error: AuraColors.debitRed,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AuraColors.canvas,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AuraColors.canvas,
        foregroundColor: AuraColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AuraColors.ink,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -1.2, color: AuraColors.ink),
        headlineMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.8, color: AuraColors.ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AuraColors.ink),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AuraColors.ink),
        bodyMedium: TextStyle(color: AuraColors.ink, height: 1.45),
        labelLarge: TextStyle(fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AuraColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AuraColors.ink,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AuraColors.ink,
          side: const BorderSide(color: AuraColors.cardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AuraColors.ink,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AuraColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AuraColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AuraColors.ink, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AuraColors.ink,
        contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white, fontSize: 13.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AuraColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AuraColors.ink : AuraColors.divider,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AuraColors.ink),
      dividerTheme: const DividerThemeData(color: AuraColors.divider, thickness: 1, space: 1),
    );
  }
}
