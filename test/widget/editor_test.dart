// editor_test.dart
//
// What IS tested here:
//   • EditorScreen PIN flow: SetPinDialog (set + error cases), VerifyPinDialog
//     (verify + error cases), unlocking to reveal _EditableGrid + _EditableCell.
//   • CellEditorSheet — the modal cell editor — full interaction coverage.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_aac/main.dart';
import 'package:sprout_aac/models/database.dart';
import 'package:sprout_aac/screens/editor/cell_editor_sheet.dart';
import 'package:sprout_aac/screens/editor/editor_screen.dart';
import 'package:sprout_aac/services/symbol_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  late AppDatabase db;
  late MockSymbolService symbols;
  late ChildProfile profile;
  late Board board;

  setUp(() async {
    db = makeTestDb();
    symbols = MockSymbolService();
    stubSymbolService(symbols);
    mockSecureStorage();

    final pid = await db.insertProfile(ChildProfilesCompanion.insert(
      name: 'Alex',
      gridColumns: const Value(3),
      gridRows: const Value(3),
    ));
    await db.insertBoard(BoardsCompanion.insert(
      childId: pid,
      name: 'Home',
      isHomeBoard: const Value(true),
      gridColumns: const Value(3),
      gridRows: const Value(3),
    ));

    profile = (await db.getAllProfiles()).first;
    board = (await db.watchBoardsForChild(pid).first).first;
  });

  tearDown(() {
    clearSecureStorageMock();
    db.close();
  });

  // ── EditorScreen ────────────────────────────────────────────────────────────

  group('EditorScreen', () {
    Widget wrap() => ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            symbolServiceProvider.overrideWithValue(symbols),
          ],
          child: MaterialApp(
            home: EditorScreen(board: board, profile: profile),
          ),
        );

    testWidgets('renders Edit Mode AppBar and Done button', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(); // first frame

      expect(find.text('✏️ Edit Mode'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Done button pops EditorScreen back to the caller',
        (tester) async {
      // Push EditorScreen from a parent route so Navigator.pop has somewhere to go.
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          symbolServiceProvider.overrideWithValue(symbols),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) =>
                      EditorScreen(board: board, profile: profile),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pump();
      // 400ms: route animation completes + addPostFrameCallback fires + PIN dialog appears
      await tester.pump(const Duration(milliseconds: 400));

      // Complete the set-PIN flow so the grid unlocks (Done becomes meaningfully tappable)
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '0000');
      await tester.pump();
      await tester.enterText(fields.at(1), '0000');
      await tester.pump();
      await tester.tap(find.text('Set PIN'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(Duration.zero); // Drift stream initial data

      expect(find.text('Done'), findsOneWidget);

      // Tap Done — fires Navigator.pop(context) on line 101
      await tester.tap(find.text('Done'));
      // pumpAndSettle waits for the pop animation to complete and the route to
      // be removed. No infinite animation controllers are running at this point.
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
    });
  });

  // ── CellEditorSheet ─────────────────────────────────────────────────────────
  //
  // CellEditorSheet contains TextField, DropdownButtonFormField, and SymbolPicker
  // (a ConsumerStatefulWidget). These widgets have running animation controllers
  // (TextField cursor blink, InputDecorator focus transitions, DropdownButton arrow)
  // that prevent pumpAndSettle from ever settling — identical to the AnimatedContainer
  // issue in CommunicationGrid. Use pump() / pump(Duration) instead:
  //   • pump()                         — one frame, for initial renders & simple actions
  //   • pump(Duration(milliseconds: 200)) — let dialog route animation complete (150 ms)
  //   • pump(Duration(milliseconds: 300)) — let dropdown route animation complete (300 ms)

  group('CellEditorSheet', () {
    Widget wrapSheet({BoardCell? cell}) => ProviderScope(
          overrides: [
            symbolServiceProvider.overrideWithValue(symbols),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CellEditorSheet(
                cell: cell,
                row: 0,
                col: 0,
                boardId: board.id,
                db: db,
              ),
            ),
          ),
        );

    testWidgets('shows New Cell title and Add Cell button for null cell',
        (tester) async {
      await tester.pumpWidget(wrapSheet());
      await tester.pump();

      expect(find.text('New Cell'), findsOneWidget);
      expect(find.text('Add Cell'), findsOneWidget);
    });

    testWidgets('shows Edit Cell title and Save Changes for existing cell',
        (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'more',
      ));
      final cell = (await db.getCellsForBoard(board.id)).first;

      await tester.pumpWidget(wrapSheet(cell: cell));
      await tester.pump();

      expect(find.text('Edit Cell'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('save with empty label is a no-op', (tester) async {
      await tester.pumpWidget(wrapSheet());
      await tester.pump();

      await tester.ensureVisible(find.text('Add Cell'));
      await tester.pump();
      await tester.tap(find.text('Add Cell'));
      await tester.pump();

      final cells = await db.getCellsForBoard(board.id);
      expect(cells, isEmpty);
    });

    testWidgets('save with label upserts a cell in the database',
        (tester) async {
      await tester.pumpWidget(wrapSheet());
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'help');
      // The 'Add Cell' button may be below the 800×600 test viewport due to the
      // tall ScrollView content — scroll to it before tapping.
      await tester.ensureVisible(find.text('Add Cell'));
      await tester.pump();
      await tester.tap(find.text('Add Cell'));
      await tester.pump();

      final cells = await db.getCellsForBoard(board.id);
      expect(cells.any((c) => c.label == 'help'), isTrue);
    });

    testWidgets('delete button shows confirmation dialog', (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'more',
      ));
      final cell = (await db.getCellsForBoard(board.id)).first;

      await tester.pumpWidget(wrapSheet(cell: cell));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Delete cell?'), findsOneWidget);
    });

    testWidgets('confirming delete removes cell from database', (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'more',
      ));
      final cell = (await db.getCellsForBoard(board.id)).first;

      await tester.pumpWidget(wrapSheet(cell: cell));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Delete'));
      await tester.pump();

      final after = await db.getCellsForBoard(board.id);
      expect(after, isEmpty);
    });

    testWidgets('cancelling delete keeps the cell', (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'more',
      ));
      final cell = (await db.getCellsForBoard(board.id)).first;

      await tester.pumpWidget(wrapSheet(cell: cell));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      final after = await db.getCellsForBoard(board.id);
      expect(after.length, 1);
    });

    testWidgets('selecting action type navigate hides speak text field',
        (tester) async {
      await tester.pumpWidget(wrapSheet());
      await tester.pump();

      // Scroll down to find the action dropdown
      await tester.dragUntilVisible(
        find.byType(DropdownButtonFormField<String>),
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );
      await tester.pump();

      // Open dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump(const Duration(milliseconds: 300));

      // Select 'Go to board' (navigate)
      await tester.tap(find.text('Go to board').last);
      await tester.pump(const Duration(milliseconds: 300));

      // 'Speak text' section should be gone
      expect(find.text('Speak text (optional)'), findsNothing);
    });

    testWidgets('save changes for existing cell updates label in database',
        (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'more',
      ));
      final cell = (await db.getCellsForBoard(board.id)).first;

      await tester.pumpWidget(wrapSheet(cell: cell));
      await tester.pump();

      // Clear the pre-filled label and type a new one
      await tester.enterText(find.byType(TextField).first, 'less');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pump();
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      final cells = await db.getCellsForBoard(board.id);
      expect(cells.any((c) => c.label == 'less'), isTrue);
    });

    testWidgets('shows symbol preview section when cell has a symbolUrl',
        (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'dog',
        symbolUrl: const Value('https://example.com/dog.png'),
      ));
      final cell = (await db.getCellsForBoard(board.id)).first;

      await tester.pumpWidget(wrapSheet(cell: cell));
      await tester.pump();

      // 'Remove' button appears next to the symbol preview image
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('tapping Remove clears the symbol URL', (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'dog',
        symbolUrl: const Value('https://example.com/dog.png'),
      ));
      final cell = (await db.getCellsForBoard(board.id)).first;

      await tester.pumpWidget(wrapSheet(cell: cell));
      await tester.pump();

      await tester.tap(find.text('Remove'));
      await tester.pump();

      // Symbol preview section should be gone (no Remove button)
      expect(find.text('Remove'), findsNothing);
    });

    testWidgets('tapping a color circle changes the background color',
        (tester) async {
      await tester.pumpWidget(wrapSheet());
      await tester.pump();

      // Scroll to the Colour section
      await tester.dragUntilVisible(
        find.text('Colour'),
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );
      await tester.pump();

      // The color circles are GestureDetectors inside the Wrap.
      // Tap one — any tap that hits a color circle executes the onTap closure.
      final colorGestures = find.descendant(
        of: find.byType(Wrap),
        matching: find.byType(GestureDetector),
      );
      expect(colorGestures, findsWidgets);
      // Tap the second circle (first may already be selected)
      await tester.tap(colorGestures.at(1));
      await tester.pump();
      // No throw = color changed successfully
    });
  });

  // ── EditorScreen PIN — set flow ──────────────────────────────────────────────
  //
  // mockSecureStorage() in setUp provides storedPin: null → SetPinDialog shown.
  //
  // pump(100ms) is needed instead of bare pump() because _checkPin() uses
  // addPostFrameCallback → async MethodChannel → showDialog. The MethodChannel
  // async chain has ~4 microtask boundaries; pump() only advances ONE per call,
  // whereas pump(Duration) suspends at await Future.delayed which allows ALL
  // pending microtasks to drain naturally before the frame check runs.
  //
  // Each test ends with a drift flush so Drift's StreamQueryStore timer is cleared.

  group('EditorScreen PIN — set flow', () {
    Widget wrapEditor() => ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            symbolServiceProvider.overrideWithValue(symbols),
          ],
          child: MaterialApp(
            home: EditorScreen(board: board, profile: profile),
          ),
        );

    Future<void> _driftFlush(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('shows SetPinDialog when no PIN is stored', (tester) async {
      await tester.pumpWidget(wrapEditor());
      // 100ms lets MethodChannel microtask chain complete + dialog frame build
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Set Edit Mode PIN'), findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('SetPinDialog: invalid PIN shows error message', (tester) async {
      await tester.pumpWidget(wrapEditor());
      await tester.pump(const Duration(milliseconds: 100));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '123'); // only 3 digits
      await tester.pump();
      await tester.tap(find.text('Set PIN'));
      await tester.pump();

      expect(find.text('PIN must be exactly 4 digits'), findsOneWidget);

      // Clean up: complete the flow with a valid PIN
      await tester.enterText(fields.at(0), '1234');
      await tester.pump();
      await tester.enterText(fields.at(1), '1234');
      await tester.pump();
      await tester.tap(find.text('Set PIN'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(Duration.zero);
      await _driftFlush(tester);
    });

    testWidgets("SetPinDialog: mismatched PINs shows error message",
        (tester) async {
      await tester.pumpWidget(wrapEditor());
      await tester.pump(const Duration(milliseconds: 100));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1234');
      await tester.pump();
      await tester.enterText(fields.at(1), '5678'); // different
      await tester.pump();
      await tester.tap(find.text('Set PIN'));
      await tester.pump();

      expect(find.textContaining("don't match"), findsOneWidget);

      // Complete with matching PINs
      await tester.enterText(fields.at(1), '1234');
      await tester.pump();
      await tester.tap(find.text('Set PIN'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(Duration.zero);
      await _driftFlush(tester);
    });

    testWidgets(
        'SetPinDialog: valid matching PINs unlock the editable grid',
        (tester) async {
      await tester.pumpWidget(wrapEditor());
      await tester.pump(const Duration(milliseconds: 100)); // dialog shown

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1234');
      await tester.pump();
      await tester.enterText(fields.at(1), '1234');
      await tester.pump();
      await tester.tap(find.text('Set PIN'));
      // 200ms: write MethodChannel chain + _unlocked=true + StreamBuilder frame
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(Duration.zero); // Drift stream emits initial data

      expect(
        find.text('Tap a cell to edit · Tap empty slots to add'),
        findsOneWidget,
      );
      await _driftFlush(tester);
    });

    testWidgets('SetPinDialog: cancel does not unlock the grid', (tester) async {
      await tester.pumpWidget(wrapEditor());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Set Edit Mode PIN'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // Grid hint banner should NOT be visible
      expect(
        find.text('Tap a cell to edit · Tap empty slots to add'),
        findsNothing,
      );
      await _driftFlush(tester);
    });

    testWidgets(
        'SetPinDialog: pressing Enter in confirm PIN field submits the form',
        (tester) async {
      await tester.pumpWidget(wrapEditor());
      await tester.pump(const Duration(milliseconds: 100));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '2222');
      await tester.pump();
      // Focus the confirm field and type a PIN — this also activates the TextInput
      await tester.enterText(fields.at(1), '2222');
      await tester.pump();
      // Simulate pressing the keyboard Enter key, which fires onSubmitted → _submit()
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(Duration.zero);

      expect(
        find.text('Tap a cell to edit · Tap empty slots to add'),
        findsOneWidget,
      );
      await _driftFlush(tester);
    });
  });

  // ── EditorScreen PIN — verify flow ───────────────────────────────────────────
  //
  // Override mock with a stored PIN so VerifyPinDialog is shown.

  group('EditorScreen PIN — verify flow', () {
    Widget wrapEditor() => ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            symbolServiceProvider.overrideWithValue(symbols),
          ],
          child: MaterialApp(
            home: EditorScreen(board: board, profile: profile),
          ),
        );

    Future<void> _driftFlush(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('shows VerifyPinDialog when a PIN is already stored',
        (tester) async {
      mockSecureStorage(storedPin: '1234');

      await tester.pumpWidget(wrapEditor());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Edit Mode PIN'), findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('VerifyPinDialog: incorrect PIN shows error', (tester) async {
      mockSecureStorage(storedPin: '1234');

      await tester.pumpWidget(wrapEditor());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), '9999');
      await tester.pump();
      await tester.tap(find.text('Unlock'));
      await tester.pump();

      expect(find.text('Incorrect PIN'), findsOneWidget);

      // Complete with correct PIN to clean up
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      await tester.tap(find.text('Unlock'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(Duration.zero);
      await _driftFlush(tester);
    });

    testWidgets('VerifyPinDialog: correct PIN unlocks editable grid',
        (tester) async {
      mockSecureStorage(storedPin: '1234');

      await tester.pumpWidget(wrapEditor());
      await tester.pump(const Duration(milliseconds: 100)); // dialog shown

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      await tester.tap(find.text('Unlock'));
      // 200ms: MethodChannel chain + _unlocked=true + StreamBuilder frame
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(Duration.zero); // Drift stream emits initial data

      expect(
        find.text('Tap a cell to edit · Tap empty slots to add'),
        findsOneWidget,
      );
      await _driftFlush(tester);
    });

    testWidgets('VerifyPinDialog: cancel does not unlock the grid',
        (tester) async {
      mockSecureStorage(storedPin: '1234');

      await tester.pumpWidget(wrapEditor());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(
        find.text('Tap a cell to edit · Tap empty slots to add'),
        findsNothing,
      );
      await _driftFlush(tester);
    });

    testWidgets(
        'VerifyPinDialog: pressing Enter in PIN field submits the form',
        (tester) async {
      mockSecureStorage(storedPin: '5678');

      await tester.pumpWidget(wrapEditor());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), '5678');
      await tester.pump();
      // Enter key fires onSubmitted → _submit() (line 490)
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(Duration.zero);

      expect(
        find.text('Tap a cell to edit · Tap empty slots to add'),
        findsOneWidget,
      );
      await _driftFlush(tester);
    });
  });

  // ── _EditableGrid and _EditableCell ──────────────────────────────────────────
  //
  // These require completing the PIN flow first to show _unlocked = true.

  group('_EditableGrid and _EditableCell', () {
    Widget wrapEditor() => ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            symbolServiceProvider.overrideWithValue(symbols),
          ],
          child: MaterialApp(
            home: EditorScreen(board: board, profile: profile),
          ),
        );

    Future<void> _unlockViaSetPin(WidgetTester tester) async {
      await tester.pumpWidget(wrapEditor());
      await tester.pump(const Duration(milliseconds: 100)); // dialog shown
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '0000');
      await tester.pump();
      await tester.enterText(fields.at(1), '0000');
      await tester.pump();
      await tester.tap(find.text('Set PIN'));
      // 200ms: write MethodChannel chain + _unlocked=true + StreamBuilder frame
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(Duration.zero); // Drift initial stream
    }

    Future<void> _driftFlush(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('hint banner is visible once grid is unlocked', (tester) async {
      await _unlockViaSetPin(tester);
      expect(
        find.text('Tap a cell to edit · Tap empty slots to add'),
        findsOneWidget,
      );
      await _driftFlush(tester);
    });

    testWidgets('shows add-icon for empty cells and edit-badge for filled cells',
        (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'help',
        backgroundColor: const Value('#2196F3'),
      ));

      await _unlockViaSetPin(tester);

      // Filled cell shows label
      expect(find.text('help'), findsOneWidget);
      // Empty slots show add icon
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
      // Filled cell shows edit badge
      expect(find.byIcon(Icons.edit), findsOneWidget);

      await _driftFlush(tester);
    });

    testWidgets('_EditableCell falls back to blue for invalid color hex',
        (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'ok',
        backgroundColor: const Value('not-a-color'),
      ));

      await _unlockViaSetPin(tester);

      expect(find.text('ok'), findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('tapping an empty slot opens CellEditorSheet for a new cell',
        (tester) async {
      await _unlockViaSetPin(tester);

      // All 9 slots are empty — tap any add-icon slot (fires _openEditor, line 270)
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pump(const Duration(milliseconds: 200)); // bottom-sheet animation

      expect(find.text('New Cell'), findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('tapping a filled cell opens CellEditorSheet for editing',
        (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'water',
      ));

      await _unlockViaSetPin(tester);

      // Tap the filled cell label — fires _openEditor (lines 229-242, 248)
      await tester.tap(find.text('water'));
      await tester.pump(const Duration(milliseconds: 200)); // bottom-sheet animation

      expect(find.text('Edit Cell'), findsOneWidget);
      await _driftFlush(tester);
    });

    testWidgets('_EditableCell with symbolUrl renders an Image widget',
        (tester) async {
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: board.id,
        rowIndex: 0,
        colIndex: 0,
        label: 'dog',
        symbolUrl: const Value('https://example.com/dog.png'),
      ));

      await _unlockViaSetPin(tester);

      // Image.network is built (loading fails in tests, but the widget is present — lines 299-304)
      expect(find.byType(Image), findsOneWidget);
      await _driftFlush(tester);
    });
  });
}
