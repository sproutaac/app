import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprout_aac/onboarding/onboarding_flow.dart';
import 'package:sprout_aac/onboarding/onboarding_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget _gate({required bool complete}) => ProviderScope(
        overrides: [
          onboardingCompleteProvider.overrideWith((_) => complete),
        ],
        child: const MaterialApp(
          home: OnboardingGate(child: Text('main screen')),
        ),
      );

  testWidgets('shows child when onboarding is complete', (tester) async {
    await tester.pumpWidget(_gate(complete: true));
    await tester.pumpAndSettle();

    expect(find.text('main screen'), findsOneWidget);
    expect(find.text('Sprout'), findsNothing);
  });

  testWidgets('shows OnboardingFlow when onboarding is not complete',
      (tester) async {
    await tester.pumpWidget(_gate(complete: false));
    await tester.pumpAndSettle();

    expect(find.text('Sprout'), findsOneWidget);
    expect(find.text("Let's go"), findsOneWidget);
    expect(find.text('main screen'), findsNothing);
  });

  testWidgets('fails open — shows child when provider throws', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCompleteProvider
              .overrideWith((_) => throw Exception('fail')),
        ],
        child: const MaterialApp(
          home: OnboardingGate(child: Text('main screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('main screen'), findsOneWidget);
  });

  testWidgets('shows loading indicator while provider is resolving',
      (tester) async {
    // A Completer that never completes keeps the provider in loading state
    // without creating a pending timer.
    final completer = Completer<bool>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCompleteProvider
              .overrideWith((_) => completer.future),
        ],
        child: const MaterialApp(
          home: OnboardingGate(child: Text('main screen')),
        ),
      ),
    );
    // pump one frame — provider is still loading
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete the future so the widget tree can be cleaned up.
    completer.complete(true);
    await tester.pumpAndSettle();
  });

  testWidgets('OnboardingFlow shows welcome step on first render',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OnboardingFlow()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sprout'), findsOneWidget);
    expect(find.text("Let's go"), findsOneWidget);
  });

}
