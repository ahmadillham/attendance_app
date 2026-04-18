import 'package:flutter/material.dart';

/// Theme constants — Clean & Minimal Design System
/// Muted palette with soft neutrals and restrained accents.

// ─── Color Palette ───────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Primary — Slate Blue (muted, professional)
  static const Color primary = Color(0xFF4A6CF7);
  static const Color primaryDark = Color(0xFF3B5DE7);
  static const Color primaryLight = Color(0xFFB4C6FC);
  static const Color primarySurface = Color(0xFFF0F3FF);
  static const Color primaryGlow = Color(0x0F4A6CF7); // 6% opacity

  // Accent — Soft Teal (subtle)
  static const Color accent = Color(0xFF5B9A8B);
  static const Color accentDark = Color(0xFF4A8A7B);
  static const Color accentSurface = Color(0xFFEDF5F3);

  // Status — Muted tones
  static const Color success = Color(0xFF4CAF7D);
  static const Color successSurface = Color(0xFFEDF7F1);
  static const Color warning = Color(0xFFE5A84B);
  static const Color warningSurface = Color(0xFFFDF5E9);
  static const Color danger = Color(0xFFE5574F);
  static const Color dangerSurface = Color(0xFFFDEDEC);
  static const Color info = Color(0xFF4A6CF7);

  // Neutrals — Warm Gray
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE8ECF1);
  static const Color borderLight = Color(0xFFF2F4F7);
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF5A6178);
  static const Color textMuted = Color(0xFF8B93A7);
  static const Color overlay = Color(0x4D0F172A); // 30% opacity
}

// ─── Typography ──────────────────────────────────────────────────
class AppFonts {
  AppFonts._();

  static const double h1 = 26;
  static const double h2 = 20;
  static const double h3 = 16;
  static const double body = 14;
  static const double caption = 12;
  static const double small = 11;
}

// ─── Spacing ─────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

// ─── Border Radius ───────────────────────────────────────────────
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;
}

// ─── Shadows — Minimal, barely-there ─────────────────────────────
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          offset: const Offset(0, 1),
          blurRadius: 4,
        ),
      ];

  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          offset: const Offset(0, 1),
          blurRadius: 8,
        ),
      ];

  static List<BoxShadow> get medium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          offset: const Offset(0, 2),
          blurRadius: 12,
        ),
      ];

  static List<BoxShadow> get glow => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.15),
          offset: const Offset(0, 4),
          blurRadius: 12,
        ),
      ];
}

// ─── Theme Data ──────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: AppFonts.h3,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: AppFonts.body,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: AppFonts.body,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: AppFonts.body,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: AppFonts.body),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: AppFonts.body),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: AppFonts.h1, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        displayMedium: TextStyle(fontSize: AppFonts.h2, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        displaySmall: TextStyle(fontSize: AppFonts.h3, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        bodyLarge: TextStyle(fontSize: AppFonts.body, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontSize: AppFonts.caption, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodySmall: TextStyle(fontSize: AppFonts.small, fontWeight: FontWeight.w400, color: AppColors.textMuted),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400, fontSize: 11),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
