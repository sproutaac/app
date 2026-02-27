// ============================================================
// main.dart — Sprout AAC entry point
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'constants/app_theme.dart';
import 'models/database.dart';
import 'onboarding/onboarding_flow.dart';
import 'screens/home/profile_selection_screen.dart';

// Global database provider — single instance for app lifetime
final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    const ProviderScope(
      child: SproutApp(),
    ),
  );
}

class SproutApp extends ConsumerWidget {
  const SproutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Sprout AAC',
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
