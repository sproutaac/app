import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sprout_aac/models/database.dart';

import '../helpers/test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = makeTestDb());
  tearDown(() => db.close());

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<int> insertProfile({String name = 'Alex', int cols = 3}) =>
      db.insertProfile(ChildProfilesCompanion.insert(
        name: name,
        gridColumns: Value(cols),
        gridRows: Value(cols),
      ));

  Future<int> insertBoard(int childId, {bool home = true}) =>
      db.insertBoard(BoardsCompanion.insert(
        childId: childId,
        name: 'Home',
        isHomeBoard: Value(home),
        gridColumns: const Value(3),
        gridRows: const Value(3),
      ));

  Future<int> insertCell(int boardId, {int row = 0, int col = 0}) =>
      db.upsertCell(BoardCellsCompanion.insert(
        boardId: boardId,
        rowIndex: row,
        colIndex: col,
        label: 'more',
      ));

  // ── Profiles ─────────────────────────────────────────────────────────────

  group('ChildProfiles', () {
    test('insertProfile returns an id', () async {
      final id = await insertProfile();
      expect(id, greaterThan(0));
    });

    test('getAllProfiles returns inserted profiles', () async {
      await insertProfile(name: 'Alex');
      await insertProfile(name: 'Sam');
      final all = await db.getAllProfiles();
      expect(all.length, 2);
      expect(all.map((p) => p.name), containsAll(['Alex', 'Sam']));
    });

    test('watchAllProfiles emits profile list', () async {
      await insertProfile(name: 'Alex');
      final profiles = await db.watchAllProfiles().first;
      expect(profiles.length, 1);
      expect(profiles.first.name, 'Alex');
    });

    test('updateProfile persists changes', () async {
      final id = await insertProfile(name: 'Alex');
      final profiles = await db.getAllProfiles();
      final updated = profiles.first.copyWith(name: 'Alexia');
      final success = await db.updateProfile(updated);
      expect(success, isTrue);
      final after = await db.getAllProfiles();
      expect(after.first.name, 'Alexia');
    });
  });

  // ── Boards ────────────────────────────────────────────────────────────────

  group('Boards', () {
    test('insertBoard returns an id', () async {
      final pid = await insertProfile();
      final bid = await insertBoard(pid);
      expect(bid, greaterThan(0));
    });

    test('getHomeBoardForChild returns the home board', () async {
      final pid = await insertProfile();
      await insertBoard(pid, home: true);
      final board = await db.getHomeBoardForChild(pid);
      expect(board, isNotNull);
      expect(board!.isHomeBoard, isTrue);
    });

    test('getHomeBoardForChild returns null when none exists', () async {
      final pid = await insertProfile();
      await insertBoard(pid, home: false);
      final board = await db.getHomeBoardForChild(pid);
      expect(board, isNull);
    });

    test('watchBoardsForChild emits boards for the given child', () async {
      final pid = await insertProfile();
      await insertBoard(pid);
      final boards = await db.watchBoardsForChild(pid).first;
      expect(boards.length, 1);
    });
  });

  // ── Cells ─────────────────────────────────────────────────────────────────

  group('BoardCells', () {
    test('upsertCell inserts a new cell', () async {
      final pid = await insertProfile();
      final bid = await insertBoard(pid);
      await insertCell(bid, row: 0, col: 0);
      final cells = await db.watchCellsForBoard(bid).first;
      expect(cells.length, 1);
      expect(cells.first.label, 'more');
    });

    test('upsertCell updates an existing cell on row/col conflict', () async {
      final pid = await insertProfile();
      final bid = await insertBoard(pid);
      // Insert then update via upsert (same row/col, different boardId key)
      await db.upsertCell(BoardCellsCompanion.insert(
        boardId: bid,
        rowIndex: 0,
        colIndex: 0,
        label: 'help',
      ));
      final cells = await db.watchCellsForBoard(bid).first;
      expect(cells.first.label, 'help');
    });

    test('deleteCell removes the cell', () async {
      final pid = await insertProfile();
      final bid = await insertBoard(pid);
      await insertCell(bid);
      final before = await db.watchCellsForBoard(bid).first;
      await db.deleteCell(before.first.id);
      final after = await db.watchCellsForBoard(bid).first;
      expect(after, isEmpty);
    });

    test('watchCellsForBoard returns cells ordered by row then col', () async {
      final pid = await insertProfile();
      final bid = await insertBoard(pid);
      await db.upsertCell(BoardCellsCompanion.insert(
          boardId: bid, rowIndex: 1, colIndex: 0, label: 'b'));
      await db.upsertCell(BoardCellsCompanion.insert(
          boardId: bid, rowIndex: 0, colIndex: 1, label: 'a'));
      final cells = await db.watchCellsForBoard(bid).first;
      expect(cells[0].label, 'a'); // row 0, col 1
      expect(cells[1].label, 'b'); // row 1, col 0
    });
  });

  // ── Usage & Prediction ────────────────────────────────────────────────────

  group('UsageEvents & PredictionWeights', () {
    test('recordTap inserts a usage event', () async {
      final pid = await insertProfile();
      final bid = await insertBoard(pid);
      final cellId = await insertCell(bid);
      // Should not throw
      await db.recordTap(pid, cellId, 'more');
    });

    test('updatePredictionWeight inserts a new row', () async {
      final pid = await insertProfile();
      await db.updatePredictionWeight(pid, 'more', 'please');
      final preds = await db.getPredictions(pid, 'more');
      expect(preds, contains('please'));
    });

    test('updatePredictionWeight increments frequency on conflict', () async {
      final pid = await insertProfile();
      await db.updatePredictionWeight(pid, 'more', 'please');
      await db.updatePredictionWeight(pid, 'more', 'please');
      // Should not throw — ON CONFLICT increments frequency
      final preds = await db.getPredictions(pid, 'more');
      expect(preds, contains('please'));
    });

    test('getPredictions returns top-N by frequency', () async {
      final pid = await insertProfile();
      await db.updatePredictionWeight(pid, 'I', 'want');
      await db.updatePredictionWeight(pid, 'I', 'want');
      await db.updatePredictionWeight(pid, 'I', 'like');
      final preds = await db.getPredictions(pid, 'I');
      // 'want' has higher frequency so should come first
      expect(preds.first, 'want');
    });

    test('getPredictions returns empty for unknown preceding label', () async {
      final pid = await insertProfile();
      final preds = await db.getPredictions(pid, 'unknown');
      expect(preds, isEmpty);
    });
  });
}
