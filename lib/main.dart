// ============================================================
// main.dart — Sprout AAC entry point
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_theme.dart';
import 'models/database.dart';
import 'onboarding/onboarding_flow.dart';
import 'onboarding/onboarding_provider.dart';
import 'screens/home/profile_selection_screen.dart';

// Global database provider — single instance for app lifetime
final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read onboarding flag synchronously at startup so OnboardingGate
  // renders immediately with no loading spinner.
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_complete') ?? false;

  // Lock to portrait — important for consistent motor planning
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Full-screen immersive mode in communication mode
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        // Pre-populate with the value we already have so the gate
        // never shows a loading frame.
        onboardingCompleteProvider.overrideWith((_) => onboardingDone),
      ],
      child: const SproutApp(),
    ),
  );
}

class SproutApp extends ConsumerWidget {
  const SproutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'SproutAAC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // High contrast mode respects system accessibility settings
      highContrastTheme: AppTheme.highContrast,
      home: const OnboardingGate(
        child: ProfileSelectionScreen(),
      ),
    );
  }
}
