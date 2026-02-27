import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../models/database.dart';
import '../onboarding_provider.dart';

class StepDone extends ConsumerStatefulWidget {
  const StepDone({super.key});

  @override
  ConsumerState<StepDone> createState() => _StepDoneState();
}

class _StepDoneState extends ConsumerState<StepDone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn));

    _controller.forward();
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    // Let the animation play first
    await Future.delayed(const Duration(milliseconds: 200));

    // Create the profile and board from onboarding state before marking complete.
    // Wrapped in try/catch so a DB error never blocks the user from proceeding.
    try {
      await _createFromOnboarding();
    } catch (_) {
      // Silently fail — user can create a profile manually from the home screen
    }

    await ref.read(onboardingProvider.notifier).complete();
  }

  Future<void> _createFromOnboarding() async {
    final state = ref.read(onboardingProvider);
    final db = ref.read(dbProvider);

    final template = state.selectedTemplate;
    final gridSize = template?.ageRange.defaultGridSize ?? 3;

    final accessMethodStr =
        state.accessMethod == AccessMethod.switchAccess ? 'switch_single' : 'touch';

    // 1. Create child profile
    final profileId = await db.insertProfile(ChildProfilesCompanion.insert(
      name: state.childName.isNotEmpty ? state.childName : 'My Child',
      gridColumns: Value(gridSize),
      gridRows: Value(gridSize),
      accessMethod: Value(accessMethodStr),
    ));

    // 2. Create home board
    final boardId = await db.insertBoard(BoardsCompanion.insert(
      childId: profileId,
      name: 'Home Board',
      isHomeBoard: const Value(true),
      gridColumns: Value(gridSize),
      gridRows: Value(gridSize),
    ));

    // 3. Populate cells from the selected OBF template
    if (template != null) {
      await _insertCellsFromTemplate(db, boardId, template);
    }
  }

  Future<void> _insertCellsFromTemplate(
    AppDatabase db,
    int boardId,
    StarterTemplate template,
  ) async {
    final jsonStr = await rootBundle.loadString(template.assetPath);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    for (final btn in (json['buttons'] as List<dynamic>)) {
      final label = btn['label'] as String;
      final vocalization = btn['vocalization'] as String?;
      final bgHex = _rgbToHex(btn['background_color'] as String? ?? '');

      // Only store speakText when it differs from label (e.g. "want" → "I want")
      final speakText =
          vocalization != null && vocalization != label ? vocalization : null;

      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: boardId,
        rowIndex: btn['row'] as int,
        colIndex: btn['column'] as int,
        label: label,
        speakText: Value(speakText),
        backgroundColor: Value(bgHex),
        textColor: const Value('#FFFFFF'),
      ));
    }
  }

  /// Converts "rgb(124, 179, 66)" → "#7cb342"
  String _rgbToHex(String rgb) {
    final match =
        RegExp(r'rgb\((\d+),\s*(\d+),\s*(\d+)\)').firstMatch(rgb);
    if (match == null) return '#4A90D9';
    final r = int.parse(match.group(1)!);
    final g = int.parse(match.group(2)!);
    final b = int.parse(match.group(3)!);
    return '#'
        '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final childName =
        state.childName.isNotEmpty ? state.childName : 'your child';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F5C2E), Color(0xFF1A8C45)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🌱', style: TextStyle(fontSize: 56)),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      "${childName}'s board is ready.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap any symbol to speak.\nTap the pencil to edit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.75),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              FadeTransition(
                opacity: _fadeAnim,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      // onboardingCompleteProvider will now return true,
                      // and OnboardingGate will rebuild showing the main app.
                      // No explicit navigation needed — Riverpod handles it.
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F5C2E),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text("Open the board"),
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
