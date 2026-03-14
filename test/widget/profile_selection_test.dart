import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_aac/models/database.dart';
import 'package:sprout_aac/screens/home/profile_selection_screen.dart';

import '../helpers/test_helpers.dart';

Widget _wrap(AppDatabase db) => ProviderScope(
      overrides: dbOverride(db),
      child: const MaterialApp(home: ProfileSelectionScreen()),
    );

// Flush the zero-duration timer that Drift's StreamQueryStore.markAsClosed
// schedules when a StreamBuilder is unmounted. Must run inside the test body
// (before _verifyInvariants) rather than in tearDown.
Future<void> _driftFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero); // elapse zero time to fire Duration.zero timers
}

void main() {
  late AppDatabase db;

  setUp(() => db = makeTestDb());
  tearDown(() => db.close());

  testWidgets('shows empty-state when no profiles exist', (tester) async {
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Sprout'), findsOneWidget);
    expect(find.text('Create First Profile'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('shows profiles when they exist', (tester) async {
    await db.insertProfile(ChildProfilesCompanion.insert(name: 'Alex'));

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('3×3 grid'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('shows Add Child card alongside existing profiles',
      (tester) async {
    await db.insertProfile(ChildProfilesCompanion.insert(name: 'Sam'));

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('Add Child'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('tapping Create First Profile opens dialog', (tester) async {
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create First Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Create Child Profile'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('tapping Add Child card opens dialog', (tester) async {
    await db.insertProfile(ChildProfilesCompanion.insert(name: 'Alex'));
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Child'));
    await tester.pumpAndSettle();

    expect(find.text('Create Child Profile'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('quick-add dialog creates a profile on submit', (tester) async {
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create First Profile'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, '').first, 'Jordan');

    // Select 4×4 grid
    await tester.tap(find.text('4×4\n16 cells'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final profiles = await db.getAllProfiles();
    expect(profiles.any((p) => p.name == 'Jordan'), isTrue);

    await _driftFlush(tester);
  });

  testWidgets('quick-add dialog cancel dismisses without saving',
      (tester) async {
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create First Profile'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Create Child Profile'), findsNothing);
    expect(await db.getAllProfiles(), isEmpty);

    await _driftFlush(tester);
  });

  testWidgets('quick-add Create button ignores empty name', (tester) async {
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create First Profile'));
    await tester.pumpAndSettle();

    // Do not enter a name — tap Create directly
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Dialog should still be open
    expect(find.text('Create Child Profile'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('tapping a profile card navigates to CommunicationScreen',
      (tester) async {
    await db.insertProfile(ChildProfilesCompanion.insert(name: 'Alex'));

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();

    // CommunicationScreen has no distinct text we can easily find without
    // mocking TTS, but we can verify navigation happened (ProfileSelection gone).
    expect(find.text('Who is communicating today?'), findsNothing);

    await _driftFlush(tester);
  });
}
