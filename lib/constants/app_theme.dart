// ============================================================
// app_theme.dart — Design system for Sprout AAC
//
// Follows the Sprout AAC brand guide (sproutaac/.github → brand/README.md,
// sproutaac.org/brand): Forest for primary buttons and headings, Green as the
// brand accent, Leaf and Fresh for highlights, Cream backgrounds; Lora for
// headings and the "Sprout" wordmark, DM Sans for everything else (both
// bundled in assets/fonts, SIL OFL).
//
// Design principles:
//   • High contrast ratios (WCAG AA minimum, AAA where possible)
//   • Large touch targets (minimum 60x60dp per WCAG 2.5.5)
//   • Clear visual hierarchy — children vs caregiver UI
//   • OpenDyslexic font option for readability
// Board cell colors are the Fitzgerald Key (below), not the brand palette.
// ============================================================

import 'package:flutter/material.dart';

class AppColors {
  // Brand palette (sproutaac.org/brand)
  static const forest = Color(0xFF0F5C2E); // primary buttons, headings (8.2:1 with white)
  static const green = Color(0xFF1A8C45);  // brand green, links, accents
  static const leaf = Color(0xFF3DC46A);   // accents, highlights
  static const fresh = Color(0xFFA8F0C0);  // text and glow on green
  static const cream = Color(0xFFFAF7F2);  // backgrounds

  // Roles used across the app
  static const primary = forest;
  static const primaryLight = leaf;
  static const primaryDark = Color(0xFF0A3F20);
  static const selectedTint = Color(0xFFE6F7EC); // Fresh at ~30% on white

  // Category colors for boards (high contrast pairs)
  static const categoryPeople = Color(0xFFFFD700);    // yellow
  static const categoryActions = Color(0xFF16A34A);   // green
  static const categoryFeelings = Color(0xFFDC2626);  // red
  static const categoryThings = Color(0xFF7C3AED);    // purple
  static const categoryFood = Color(0xFFEA580C);      // orange
  static const categoryPlaces = Color(0xFF0891B2);    // cyan

  // UI surfaces (the website's supporting neutrals)
  static const surface = cream;
  static const surfaceVariant = Color(0xFFE2D9CC); // line
  static const onSurface = Color(0xFF1C1C1A);      // charcoal
  static const muted = Color(0xFF6B6860);

  // Edit mode indicator — distinct from communication mode
  static const editModeBanner = Color(0xFFFEF3C7);
  static const editModeBannerText = Color(0xFF92400E);
}

class AppFonts {
  static const heading = 'Lora';   // headings and the "Sprout" wordmark
  static const body = 'DMSans';    // body text and UI
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: AppFonts.body,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.green,
          onSecondary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
        ),
        scaffoldBackgroundColor: AppColors.cream,
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
          titleTextStyle: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );

  static ThemeData get highContrast => ThemeData(
        useMaterial3: true,
        fontFamily: AppFonts.body,
        colorScheme: const ColorScheme.highContrastLight(),
        textTheme: _buildTextTheme(Brightness.light),
      );

  static TextTheme _buildTextTheme(Brightness brightness) {
    const heading = TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700);
    return TextTheme(
      displayLarge: heading,
      displayMedium: heading,
      displaySmall: heading,
      headlineLarge: heading,
      headlineMedium: heading,
      // Cell labels
      bodyLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      // Sentence bar (stays in the UI font: it's the child's message)
      headlineSmall: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: heading.copyWith(fontSize: 22),
    );
  }
}

// Cell color presets — SLPs follow color-coding conventions.
// These match the Fitzgerald Key used widely in AAC.
class FitzgeraldColors {
  static const people = Color(0xFFFFD700);   // yellow — people/pronouns
  static const verbs = Color(0xFF16A34A);    // green — actions/verbs
  static const descriptors = Color(0xFF2563EB); // blue — describing words
  static const nouns = Color(0xFFDC2626);    // red/orange — nouns/things
  static const social = Color(0xFFFDA4AF);   // pink — social words
  static const misc = Color(0xFFE5E7EB);     // gray — misc/function words

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
