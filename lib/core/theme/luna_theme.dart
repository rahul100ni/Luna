import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/phase_constants.dart';

class LunaTheme {
  static ThemeData themeForPhase(CyclePhase phase) {
    final colors = PhaseConstants.getPhaseInfo(phase).colors;
    return themeForColors(colors);
  }

  static ThemeData themeForColors(PhaseColors colors) {
    final base = ThemeData.dark();

    return base.copyWith(
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.primary,
      colorScheme: ColorScheme.dark(
        primary: colors.primary,
        secondary: colors.secondary,
        surface: colors.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: colors.onSurface,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      textTheme: _buildTextTheme(colors.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cormorantGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: colors.onSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      dividerTheme: DividerThemeData(
        color: colors.onSurface.withValues(alpha: 0.1),
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.onSurface.withValues(alpha: 0.4),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static TextTheme _buildTextTheme(Color onSurface) {
    return TextTheme(
      displayLarge: GoogleFonts.cormorantGaramond(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.cormorantGaramond(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      displaySmall: GoogleFonts.cormorantGaramond(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineLarge: GoogleFonts.cormorantGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onSurface,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurface,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: onSurface.withValues(alpha: 0.7),
        height: 1.4,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: 0.5,
      ),
    );
  }
}
