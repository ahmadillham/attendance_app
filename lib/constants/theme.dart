import 'package:flutter/material.dart';

/// Theme constants — Modern & Clean Design System
/// Refined palette with soft neutrals and premium feel.

// ─── Color Palette ───────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Primary — Deep Indigo / Violet
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color primaryLight = Color(0xFFA5B4FC);
  static const Color primarySurface = Color(0xFFEEF2FF);
  static const Color primaryGlow = Color(0x1F6366F1); // 12% opacity

  // Accent — Teal
  static const Color accent = Color(0xFF14B8A6);
  static const Color accentDark = Color(0xFF0D9488);
  static const Color accentSurface = Color(0xFFCCFBF1);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color successSurface = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSurface = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF6366F1);

  // Neutrals — Cool Gray
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF1F5F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color overlay = Color(0x660F172A); // 40% opacity
}

// ─── Typography ──────────────────────────────────────────────────
class AppFonts {
  AppFonts._();

  static const double h1 = 28;
  static const double h2 = 22;
  static const double h3 = 17;
  static const double body = 15;
  static const double caption = 13;
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

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double full = 999;
}

// ─── Shadows — Ultra-soft, modern ────────────────────────────────
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.06),
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ];

  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          offset: const Offset(0, 2),
          blurRadius: 12,
        ),
      ];

  static List<BoxShadow> get medium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          offset: const Offset(0, 4),
          blurRadius: 16,
        ),
      ];

  static List<BoxShadow> get glow => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          offset: const Offset(0, 6),
          blurRadius: 16,
        ),
      ];
}
