import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sprout_aac/models/database.dart';
import 'package:sprout_aac/services/tts_service.dart';
import 'package:sprout_aac/widgets/grid/communication_grid.dart';

import '../helpers/test_helpers.dart';

Widget _wrap({
  required List<BoardCell> cells,
  required AppDatabase db,
  required MockTtsService tts,
  required int childId,
  void Function(BoardCell)? onNavigate,
  void Function(BoardCell)? onCellTapped,
}) =>
    ProviderScope(
      overrides: [ttsServiceProvider.overrideWithValue(tts)],
      child: MaterialApp(
        home: Scaffold(
          body: CommunicationGrid(
            cells: cells,
            gridColumns: 3,
            gridRows: 3,
            childId: childId,
            db: db,
            onNavigate: onNavigate,
            onCellTapped: onCellTapped,
          ),
        ),
      ),
    );

void main() {
  late AppDatabase db;
  late MockTtsService tts;
  late int childId;
  late int boardId;

  setUp(() async {
    db = makeTestDb();
    tts = MockTtsService();
    stubTtsService(tts);

    childId = await db.insertProfile(ChildProfilesCompanion.insert(
      name: 'Alex',
      gridColumns: const Value(3),
      gridRows: const Value(3),
    ));
    boardId = await db.insertBoard(BoardsCompanion.insert(
      childId: childId,
      name: 'Home',
      isHomeBoard: const Value(true),
      gridColumns: const Value(3),
      gridRows: const Value(3),
    ));
  });

  tearDown(() => db.close());

  // Use getCellsForBoard (.get()) instead of watchCellsForBoard (.watch().first)
  // because .watch().first hangs inside FakeAsync: the stream's initial
  // emission goes through Drift's timer-based scheduler which FakeAsync
  // never advances. .get() resolves via microtask and works correctly.
  Future<List<BoardCell>> loadCells() =>
      db.getCellsForBoard(boardId);

  // CommunicationGrid uses AnimatedContainer (duration 150ms) and
  // AnimationController inside each cell. pumpAndSettle never settles
  // because the implicit animation controller keeps scheduling frames.
  // pump() (one frame) is sufficient: the grid has no async initialisation.

  testWidgets('renders cell labels', (tester) async {
    await db.upsertCell(BoardCellsCompanion.insert(
      boardId: boardId,
      rowIndex: 0,
      colIndex: 0,
      label: 'more',
    ));

    await tester.pumpWidget(
        _wrap(cells: await loadCells(), db: db, tts: tts, childId: childId));
    await tester.pump();

    expect(find.text('more'), findsOneWidget);
  });

  testWidgets('tapping a speak cell triggers TTS', (tester) async {
    await db.upsertCell(BoardCellsCompanion.insert(
      boardId: boardId,
      rowIndex: 0,
      colIndex: 0,
      label: 'more',
      actionType: const Value('speak'),
    ));

    await tester.pumpWidget(
        _wrap(cells: await loadCells(), db: db, tts: tts, childId: childId));
    await tester.pump();

    await tester.tap(find.text('more'));
    await tester.pump();

    verify(() => tts.speak('more')).called(1);
  });

  testWidgets('speak cell with speakText override speaks the override',
      (tester) async {
    await db.upsertCell(BoardCellsCompanion.insert(
      boardId: boardId,
      rowIndex: 0,
      colIndex: 0,
      label: 'more',
      actionType: const Value('speak'),
      speakText: const Value('I want more'),
    ));

    await tester.pumpWidget(
        _wrap(cells: await loadCells(), db: db, tts: tts, childId: childId));
    await tester.pump();

    await tester.tap(find.text('more'));
    await tester.pump();

    verify(() => tts.speak('I want more')).called(1);
  });

  testWidgets('tapping a navigate cell calls onNavigate', (tester) async {
    await db.upsertCell(BoardCellsCompanion.insert(
      boardId: boardId,
      rowIndex: 0,
      colIndex: 0,
      label: 'food',
      actionType: const Value('navigate'),
    ));

    BoardCell? navigated;
    await tester.pumpWidget(_wrap(
      cells: await loadCells(),
      db: db,
      tts: tts,
      childId: childId,
      onNavigate: (c) => navigated = c,
    ));
    await tester.pump();

    await tester.tap(find.text('food'));
    await tester.pump();

    expect(navigated, isNotNull);
    expect(navigated!.label, 'food');
  });

  testWidgets('tapping a backspace cell calls onCellTapped', (tester) async {
    await db.upsertCell(BoardCellsCompanion.insert(
      boardId: boardId,
      rowIndex: 0,
      colIndex: 0,
      label: '⌫',
      actionType: const Value('backspace'),
    ));

    BoardCell? tapped;
    await tester.pumpWidget(_wrap(
      cells: await loadCells(),
      db: db,
      tts: tts,
      childId: childId,
      onCellTapped: (c) => tapped = c,
    ));
    await tester.pump();

    await tester.tap(find.text('⌫'));
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped!.actionType, 'backspace');
  });

  testWidgets('tapping a clear cell calls onCellTapped', (tester) async {
    await db.upsertCell(BoardCellsCompanion.insert(
      boardId: boardId,
      rowIndex: 0,
      colIndex: 0,
      label: 'clear',
      actionType: const Value('clear'),
    ));

    BoardCell? tapped;
    await tester.pumpWidget(_wrap(
      cells: await loadCells(),
      db: db,
      tts: tts,
      childId: childId,
      onCellTapped: (c) => tapped = c,
    ));
    await tester.pump();

    await tester.tap(find.text('clear'));
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped!.actionType, 'clear');
  });

  testWidgets('invisible cell is not rendered', (tester) async {
    await db.upsertCell(BoardCellsCompanion.insert(
      boardId: boardId,
      rowIndex: 0,
      colIndex: 0,
      label: 'hidden',
      isVisible: const Value(false),
    ));

    await tester.pumpWidget(
        _wrap(cells: await loadCells(), db: db, tts: tts, childId: childId));
    await tester.pump();

    expect(find.text('hidden'), findsNothing);
  });
}
