import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // Mark complete in shared_preferences. Navigation is handled by
    // OnboardingGate which listens to onboardingCompleteProvider.
    // We delay slightly so the animation plays first.
    await Future.delayed(const Duration(milliseconds: 200));
    await ref.read(onboardingProvider.notifier).complete();
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
