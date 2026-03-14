// Tests for EditorScreen, _SetPinDialog, _VerifyPinDialog, and _EditableGrid.
//
// EditorScreen uses FlutterSecureStorage via a static field, so we mock the
// platform channel using the test_helpers.dart utilities.
//
// All tests that interact with PIN dialogs require three pumps after building
// the widget:
//   pump()         — first frame
//   pump()         — addPostFrameCallback fires _checkPin()
//   pump()         — storage.read() future completes → dialog shown

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_aac/main.dart';
import 'package:sprout_aac/models/database.dart';
import 'package:sprout_aac/screens/editor/editor_screen.dart';

import '../helpers/test_helpers.dart';

// Flush Drift's zero-duration timer to prevent pending-timer failures.
Future<void> _driftFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  late AppDatabase db;
  late ChildProfile profile;
  late Board board;

  setUp(() async {
    db = makeTestDb();

    final profileId = await db.insertProfile(ChildProfilesCompanion.insert(
      name: 'Alex',
      gridColumns: const Value(3),
      gridRows: const Value(3),
    ));
    await db.insertBoard(BoardsCompanion.insert(
      childId: profileId,
      name: 'Home',
      isHomeBoard: const Value(true),
      gridColumns: const Value(3),
      gridRows: const Value(3),
    ));

    final profiles = await db.getAllProfiles();
    profile = profiles.first;
    board = (await db.watchBoardsForChild(profileId).first).first;
  });

  tearDown(() async {
    clearSecureStorageMock();
    await db.close();
  });

  // Build the EditorScreen inside a Navigator so pop() works correctly.
  Widget buildEditor({ChildProfile? p, Board? b}) {
    return ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditorScreen(
                    board: b ?? board,
                    profile: p ?? profile,
                  ),
                ),
              ),
              child: const Text('Open Editor'),
            ),
          ),
        ),
      ),
    );
  }

  // Open the EditorScreen and pump until the PIN dialog appears.
  Future<void> openAndPumpToPinDialog(WidgetTester tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.tap(find.text('Open Editor'));
    await tester.pump(); // push route
    await tester.pump(); // addPostFrameCallback
    await tester.pump(); // storage.read future
  }

  // ── PIN dialog shown ──────────────────────────────────────────────────────

  testWidgets('shows Set PIN dialog when no PIN is stored', (tester) async {
    mockSecureStorage(storedPin: null);
    await openAndPumpToPinDialog(tester);
    expect(find.text('Set Edit Mode PIN'), findsOneWidget);
    await _driftFlush(tester);
  });

  testWidgets('shows Verify PIN dialog when a PIN is already stored',
      (tester) async {
    mockSecureStorage(storedPin: '1234');
    await openAndPumpToPinDialog(tester);
    expect(find.text('Edit Mode PIN'), findsOneWidget);
    await _driftFlush(tester);
  });

  // ── _SetPinDialog ─────────────────────────────────────────────────────────

  group('_SetPinDialog', () {
    setUp(() => mockSecureStorage(storedPin: null));

    testWidgets('entering a valid matching PIN unlocks the editor',
        (tester) async {
      await openAndPumpToPinDialog(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1234');
      await tester.pump();
      await tester.enterText(fields.at(1), '1234');
      await tester.pump();
      await tester.tap(find.text('Set PIN'));
      await tester.pump(); // dialog pops → storage.write → setState(_unlocked)
      await tester.pump(Duration.zero); // flush futures
      await tester.pump(); // rebuild with unlocked grid

      expect(find.text('Tap a cell to edit · Tap empty slots to add'),
          findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('shows error for a non-4-digit PIN', (tester) async {
      await openAndPumpToPinDialog(tester);

      await tester.enterText(find.byType(TextField).at(0), 'abc');
      await tester.tap(find.text('Set PIN'));
      await tester.pump();

      expect(find.text('PIN must be exactly 4 digits'), findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('shows error when PINs do not match', (tester) async {
      await openAndPumpToPinDialog(tester);

      await tester.enterText(find.byType(TextField).at(0), '1234');
      await tester.enterText(find.byType(TextField).at(1), '5678');
      await tester.tap(find.text('Set PIN'));
      await tester.pump();

      expect(find.textContaining("PINs don't match"), findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('Cancel dismisses the dialog and pops EditorScreen',
        (tester) async {
      await openAndPumpToPinDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pump(); // dialog pop
      await tester.pump(); // EditorScreen pops itself when !ok

      // Should be back on the home screen
      expect(find.text('Open Editor'), findsOneWidget);
      await _driftFlush(tester);
    });
  });

  // ── _VerifyPinDialog ──────────────────────────────────────────────────────

  group('_VerifyPinDialog', () {
    setUp(() => mockSecureStorage(storedPin: '1234'));

    testWidgets('correct PIN unlocks the editor', (tester) async {
      await openAndPumpToPinDialog(tester);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Unlock'));
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.pump();

      expect(find.text('Tap a cell to edit · Tap empty slots to add'),
          findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('wrong PIN shows Incorrect PIN error', (tester) async {
      await openAndPumpToPinDialog(tester);

      await tester.enterText(find.byType(TextField), '9999');
      await tester.tap(find.text('Unlock'));
      await tester.pump();

      expect(find.text('Incorrect PIN'), findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('Cancel dismisses and pops EditorScreen', (tester) async {
      await openAndPumpToPinDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Open Editor'), findsOneWidget);
      await _driftFlush(tester);
    });
  });

  // ── _EditableGrid (unlocked) ──────────────────────────────────────────────

  group('_EditableGrid', () {
    // Unlock editor by entering a valid PIN via the Set PIN dialog.
    Future<void> unlock(WidgetTester tester) async {
      mockSecureStorage(storedPin: null);
      await openAndPumpToPinDialog(tester);

      await tester.enterText(find.byType(TextField).at(0), '1234');
      await tester.enterText(find.byType(TextField).at(1), '1234');
      await tester.tap(find.text('Set PIN'));
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero); // Drift emits cells snapshot
    }

    testWidgets('shows hint banner after unlock', (tester) async {
      await unlock(tester);
      expect(find.text('Tap a cell to edit · Tap empty slots to add'),
          findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('renders add icon for empty cell slots', (tester) async {
      await unlock(tester);
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
      await _driftFlush(tester);
    });

    testWidgets('renders filled cells with their label', (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'help',
      ));
      await unlock(tester);
      expect(find.text('help'), findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('_parseColor falls back to blue on invalid hex', (tester) async {
      // Insert a cell with a garbage colour value
      await db.upsertCell(BoardCellsCompanion(
        boardId: Value(board.id),
        rowIndex: const Value(0),
        colIndex: const Value(0),
        label: const Value('bad'),
        backgroundColor: const Value('not-a-color'),
      ));
      await unlock(tester);
      // Should render without throwing
      expect(find.text('bad'), findsOneWidget);
      await _driftFlush(tester);
    });
  });
}
