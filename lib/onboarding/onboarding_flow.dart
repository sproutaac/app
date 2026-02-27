import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_provider.dart';
import 'steps/step_welcome.dart';
import 'steps/step_profile.dart';
import 'steps/step_template.dart';
import 'steps/step_personalize.dart';
import 'steps/step_done.dart';

// ─── Onboarding Flow Shell ────────────────────────────────────────────────────
//
// Wrap your existing MainApp widget with OnboardingGate:
//
//   class MyApp extends StatelessWidget {
//     @override
//     Widget build(BuildContext context) {
//       return MaterialApp(
//         home: OnboardingGate(child: ProfileSelectionScreen()),
//       );
//     }
//   }
//
// OnboardingGate checks shared_preferences on first load. If onboarding has
// never been completed, it shows the flow. After completion it shows `child`.

class OnboardingGate extends ConsumerWidget {
  final Widget child;
  const OnboardingGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncComplete = ref.watch(onboardingCompleteProvider);

    return asyncComplete.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0F5C2E),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (_, __) => child, // fail open — don't block app
      data: (complete) => complete ? child : const OnboardingFlow(),
    );
  }
}

// ─── Onboarding Flow ──────────────────────────────────────────────────────────

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 5;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAF6),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // navigation is explicit
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: [
              StepWelcome(onNext: _nextPage),
              StepProfile(onNext: _nextPage, onBack: _previousPage),
              StepTemplate(onNext: _nextPage, onBack: _previousPage),
              StepPersonalize(onNext: _nextPage, onBack: _previousPage),
              const StepDone(),
            ],
          ),
          // Progress dots (hidden on welcome and done screens)
          if (_currentPage > 0 && _currentPage < _totalPages - 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0,
              right: 0,
              child: _ProgressDots(
                current: _currentPage - 1,
                total: _totalPages - 2, // exclude welcome + done
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Progress Dots ────────────────────────────────────────────────────────────

class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1A8C45) : const Color(0xFFB8D9C4),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
