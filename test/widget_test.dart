// Smoke test for the top-level SproutApp widget.
// Full feature coverage lives in test/widget/ and test/unit/.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprout_aac/main.dart';
import 'package:sprout_aac/onboarding/onboarding_provider.dart';

import 'helpers/test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('SproutApp renders ProfileSelectionScreen after onboarding',
      (tester) async {
    mockSecureStorage();

    final db = makeTestDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingCompleteProvider.overrideWith((_) => true),
          dbProvider.overrideWithValue(db),
        ],
        child: const SproutApp(),
      ),
    );
    await tester.pumpAndSettle();

    // ProfileSelectionScreen empty-state heading
    expect(find.text('Welcome to Sprout'), findsOneWidget);

    clearSecureStorageMock();

    // Flush Drift's zero-duration StreamQueryStore.markAsClosed timer before
    // _verifyInvariants checks for pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero); // elapse zero time to fire Duration.zero timers
  });
}
