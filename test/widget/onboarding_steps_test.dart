// Tests for onboarding step widgets and shared onboarding UI components.
//
// Coverage targets (all had < 30% line coverage before this file):
//   onboarding_widgets.dart  — OnboardingStepShell, OnboardingHeading,
//                              OnboardingLabel, ChoiceChipOption,
//                              OnboardingContinueButton
//   steps/step_welcome.dart  — StepWelcome
//   steps/step_profile.dart  — StepProfile
//   steps/step_template.dart — StepTemplate
//   steps/step_personalize.dart — StepPersonalize
//   steps/step_done.dart     — StepDone
//
// Notes:
//   • StepDone initiates profile/board creation in initState. Tests use a
//     real in-memory Drift DB + mocked SymbolService so creation succeeds.
//   • StepDone and StepTemplate use AnimationController — pump with a
//     duration instead of pumpAndSettle.
//   • SharedPreferences must be mocked (setUp) so complete() doesn't crash.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sprout_aac/onboarding/onboarding.dart';
import 'package:sprout_aac/onboarding/onboarding_provider.dart';
import 'package:sprout_aac/onboarding/onboarding_widgets.dart';
import 'package:sprout_aac/onboarding/steps/step_welcome.dart';
import 'package:sprout_aac/onboarding/steps/step_profile.dart';
import 'package:sprout_aac/onboarding/steps/step_template.dart';
import 'package:sprout_aac/onboarding/steps/step_personalize.dart';
import 'package:sprout_aac/onboarding/steps/step_done.dart';

import '../helpers/test_helpers.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

/// Wraps [child] in ProviderScope + MaterialApp.
Widget _app(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── OnboardingStepShell ────────────────────────────────────────────────────
  group('OnboardingStepShell', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(_app(
        const OnboardingStepShell(child: Text('Hello')),
      ));
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('shows Back button when onBack is provided', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_app(
        OnboardingStepShell(
          onBack: () => tapped = true,
          child: const Text('Hi'),
        ),
      ));
      expect(find.text('Back'), findsOneWidget);
      await tester.tap(find.text('Back'));
      expect(tapped, isTrue);
    });

    testWidgets('hides Back button when onBack is null', (tester) async {
      await tester.pumpWidget(_app(
        const OnboardingStepShell(child: Text('Hi')),
      ));
      expect(find.text('Back'), findsNothing);
    });
  });

  // ── OnboardingHeading ──────────────────────────────────────────────────────
  group('OnboardingHeading', () {
    testWidgets('renders title without subtitle', (tester) async {
      await tester.pumpWidget(_app(
        const OnboardingHeading(title: 'My Title'),
      ));
      expect(find.text('My Title'), findsOneWidget);
    });

    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(_app(
        const OnboardingHeading(title: 'Title', subtitle: 'Some subtitle'),
      ));
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Some subtitle'), findsOneWidget);
    });
  });

  // ── OnboardingContinueButton ───────────────────────────────────────────────
  group('OnboardingContinueButton', () {
    testWidgets('fires callback when enabled', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_app(
        OnboardingContinueButton(
          label: 'Continue',
          enabled: true,
          onPressed: () => tapped = true,
        ),
      ));
      await tester.tap(find.text('Continue'));
      expect(tapped, isTrue);
    });

    testWidgets('does not fire when disabled', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_app(
        OnboardingContinueButton(
          label: 'Continue',
          enabled: false,
          onPressed: () => tapped = true,
        ),
      ));
      await tester.tap(find.text('Continue'));
      expect(tapped, isFalse);
    });
  });

  // ── StepWelcome ────────────────────────────────────────────────────────────
  group('StepWelcome', () {
    testWidgets('renders Sprout title and CTA button', (tester) async {
      await tester.pumpWidget(_app(StepWelcome(onNext: () {})));
      expect(find.text('Sprout'), findsOneWidget);
      expect(find.text("Let's go"), findsOneWidget);
    });

    testWidgets("tapping Let's go calls onNext", (tester) async {
      bool called = false;
      await tester.pumpWidget(_app(StepWelcome(onNext: () => called = true)));
      await tester.tap(find.text("Let's go"));
      expect(called, isTrue);
    });
  });

  // ── StepProfile ────────────────────────────────────────────────────────────
  group('StepProfile', () {
    // StepProfile renders a tall Column that exceeds the default 600px test
    // surface. Give it 1100px so nothing overflows.
    Future<void> pumpProfile(
      WidgetTester tester, {
      VoidCallback? onNext,
      VoidCallback? onBack,
    }) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(
        StepProfile(onNext: onNext ?? () {}, onBack: onBack ?? () {}),
      ));
    }

    testWidgets('renders name field and all age range chips', (tester) async {
      await pumpProfile(tester);
      expect(find.byType(TextField), findsOneWidget);
      for (final label in AgeRange.values.map((a) => a.label)) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('continue button is disabled with no name or age selected',
        (tester) async {
      await pumpProfile(tester);
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('continue button becomes enabled after name and age are set',
        (tester) async {
      await pumpProfile(tester);

      await tester.enterText(find.byType(TextField), 'Alex');
      await tester.pump();

      await tester.tap(find.text('2–4')); // toddler
      await tester.pump();

      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('tapping Back calls onBack', (tester) async {
      bool called = false;
      await pumpProfile(tester, onBack: () => called = true);
      await tester.tap(find.text('Back'));
      expect(called, isTrue);
    });

    testWidgets('renders access method chips', (tester) async {
      await pumpProfile(tester);
      expect(find.text('Touch screen'), findsOneWidget);
      expect(find.text('Switch access'), findsOneWidget);
    });
  });

  // ── StepTemplate ──────────────────────────────────────────────────────────
  group('StepTemplate', () {
    testWidgets('renders template cards including Big Talker', (tester) async {
      await tester.pumpWidget(_app(
        StepTemplate(onNext: () {}, onBack: () {}),
      ));
      await tester.pump();
      // Little Communicator and Growing Voice are immediately visible.
      expect(find.text('Little Communicator'), findsOneWidget);
      expect(find.text('Growing Voice'), findsOneWidget);
      // Big Talker may be off-screen — scroll the ListView to reveal it.
      await tester.scrollUntilVisible(find.text('Big Talker'), 200);
      expect(find.text('Big Talker'), findsOneWidget);
    });

    testWidgets('continue button is disabled when no template selected',
        (tester) async {
      await tester.pumpWidget(_app(
        StepTemplate(onNext: () {}, onBack: () {}),
      ));
      await tester.pump();
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('tapping a template card enables the continue button',
        (tester) async {
      await tester.pumpWidget(_app(
        StepTemplate(onNext: () {}, onBack: () {}),
      ));
      await tester.pump();

      await tester.tap(find.text('Little Communicator'));
      await tester.pump();

      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('shows Recommended badge for age-matched template',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          onboardingProvider.overrideWith((ref) {
            final n = OnboardingNotifier();
            n.setAgeRange(AgeRange.toddler); // auto-selects Little Communicator
            return n;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StepTemplate(onNext: () {}, onBack: () {}),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Recommended'), findsOneWidget);
    });

    testWidgets('tapping Back calls onBack', (tester) async {
      bool called = false;
      await tester.pumpWidget(_app(
        StepTemplate(onNext: () {}, onBack: () => called = true),
      ));
      await tester.pump();
      await tester.tap(find.text('Back'));
      expect(called, isTrue);
    });
  });

  // ── StepPersonalize ────────────────────────────────────────────────────────
  group('StepPersonalize', () {
    Future<void> pumpPersonalize(
      WidgetTester tester, {
      VoidCallback? onNext,
      VoidCallback? onBack,
    }) async {
      final db = makeTestDb();
      final symbols = MockSymbolService();
      stubSymbolService(symbols);
      final tts = MockTtsService();
      stubTtsService(tts);

      addTearDown(db.close);

      await tester.pumpWidget(ProviderScope(
        overrides: allOverrides(db: db, symbols: symbols, tts: tts),
        child: MaterialApp(
          home: Scaffold(
            body: StepPersonalize(
              onNext: onNext ?? () {},
              onBack: onBack ?? () {},
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('renders heading and Skip button', (tester) async {
      await pumpPersonalize(tester);
      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('Skip button calls onNext', (tester) async {
      bool called = false;
      await pumpPersonalize(tester, onNext: () => called = true);
      await tester.tap(find.text('Skip for now'));
      expect(called, isTrue);
    });

    testWidgets('continue button is always enabled (optional step)',
        (tester) async {
      await pumpPersonalize(tester);
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(btn.onPressed, isNotNull);
    });
  });

  // ── StepDone ───────────────────────────────────────────────────────────────
  group('StepDone', () {
    testWidgets('renders completion screen without crashing', (tester) async {
      final db = makeTestDb();
      final symbols = MockSymbolService();
      stubSymbolService(symbols);
      final tts = MockTtsService();
      stubTtsService(tts);

      addTearDown(db.close);

      await tester.pumpWidget(ProviderScope(
        overrides: allOverrides(db: db, symbols: symbols, tts: tts),
        child: const MaterialApp(home: Scaffold(body: StepDone())),
      ));

      // First frame — widget built
      await tester.pump();
      // Past the 200ms Future.delayed in _completeOnboarding
      await tester.pump(const Duration(milliseconds: 250));
      // Flush DB microtasks
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);

      // StepDone renders a done button on completion
      expect(find.text('Open the board'), findsOneWidget);
    });

    testWidgets("shows child name in completion message", (tester) async {
      final db = makeTestDb();
      final symbols = MockSymbolService();
      stubSymbolService(symbols);
      final tts = MockTtsService();
      stubTtsService(tts);

      addTearDown(db.close);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...allOverrides(db: db, symbols: symbols, tts: tts),
          onboardingProvider.overrideWith((ref) {
            final n = OnboardingNotifier();
            n.setChildName('Sam');
            return n;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: StepDone())),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 600)); // animation complete

      expect(find.textContaining("Sam"), findsWidgets);
    });
  });
}
