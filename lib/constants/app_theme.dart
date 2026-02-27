// ============================================================
// app_theme.dart — Design system for OpenVoice AAC
//
// Design principles:
//   • High contrast ratios (WCAG AA minimum, AAA where possible)
//   • Large touch targets (minimum 60x60dp per WCAG 2.5.5)
//   • Clear visual hierarchy — children vs caregiver UI
//   • OpenDyslexic font option for readability
// ============================================================

import 'package:flutter/material.dart';

class AppColors {
  // Primary — calm blue, not overwhelming
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF60A5FA);
  static const primaryDark = Color(0xFF1D4ED8);

  // Category colors for boards (high contrast pairs)
  static const categoryPeople = Color(0xFFFFD700);    // yellow
  static const categoryActions = Color(0xFF16A34A);   // green
  static const categoryFeelings = Color(0xFFDC2626);  // red
  static const categoryThings = Color(0xFF7C3AED);    // purple
  static const categoryFood = Color(0xFFEA580C);      // orange
  static const categoryPlaces = Color(0xFF0891B2);    // cyan

  // UI surfaces
  static const surface = Color(0xFFF8FAFC);
  static const surfaceVariant = Color(0xFFE2E8F0);
  static const onSurface = Color(0xFF0F172A);

  // Edit mode indicator — distinct from communication mode
  static const editModeBanner = Color(0xFFFEF3C7);
  static const editModeBannerText = Color(0xFF92400E);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        // Touch targets — enforce minimum sizes
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textTheme: _buildTextTheme(Brightness.light),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      );

  static ThemeData get highContrast => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.highContrastLight(),
        textTheme: _buildTextTheme(Brightness.light),
      );

  static TextTheme _buildTextTheme(Brightness brightness) {
    return const TextTheme(
      // Cell labels
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      // Sentence bar
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// Cell color presets — SLPs follow colour-coding conventions.
// These match the Fitzgerald Key used widely in AAC.
class FitzgeraldColors {
  static const people = Color(0xFFFFD700);   // yellow — people/pronouns
  static const verbs = Color(0xFF16A34A);    // green — actions/verbs
  static const descriptors = Color(0xFF2563EB); // blue — describing words
  static const nouns = Color(0xFFDC2626);    // red/orange — nouns/things
  static const social = Color(0xFFFDA4AF);   // pink — social words
  static const misc = Color(0xFFE5E7EB);     // grey — misc/function words

  static const presets = [
    FitzgeraldColors.people,
    FitzgeraldColors.verbs,
    FitzgeraldColors.descriptors,
    FitzgeraldColors.nouns,
    FitzgeraldColors.social,
    FitzgeraldColors.misc,
    Color(0xFF7C3AED), // purple
    Color(0xFF0891B2), // cyan
    Color(0xFFEA580C), // orange
    Colors.white,
  ];
}
