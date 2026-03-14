// editor_test.dart
//
// EditorScreen PIN-dialog interaction tests are intentionally omitted: the
// screen uses `static const _storage = FlutterSecureStorage()`, so the
// storage cannot be injected in tests.  The `_checkPin()` future is also
// unawaited (scheduled via addPostFrameCallback), which means platform-
// channel failures are swallowed silently in the fake-async test
// environment.  PIN UX is covered by manual / integration testing instead.
//
// What IS tested here:
//   • EditorScreen renders its AppBar and "Done" action.
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
  });
}
