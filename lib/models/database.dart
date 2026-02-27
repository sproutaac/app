// ============================================================
// database.dart — Drift (SQLite) schema for OpenVoice AAC
// All user data lives here first. Cloud sync is additive only.
// ============================================================

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ── Tables ────────────────────────────────────────────────────

/// A child profile. One device can hold multiple profiles
/// (e.g. siblings, or a therapist managing several students).
class ChildProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get avatarPath => text().nullable()();
  IntColumn get gridColumns => integer().withDefault(const Constant(3))();
  IntColumn get gridRows => integer().withDefault(const Constant(3))();
  TextColumn get voiceIdentifier => text().nullable()();
  RealColumn get voiceRate => real().withDefault(const Constant(0.5))();
  RealColumn get voicePitch => real().withDefault(const Constant(1.0))();
  RealColumn get voiceVolume => real().withDefault(const Constant(1.0))();
  // touch | switch_single | switch_dual
  TextColumn get accessMethod =>
      text().withDefault(const Constant('touch'))();
  IntColumn get scanSpeedMs =>
      integer().withDefault(const Constant(1500))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// A communication board. Each child has a home board + topic boards.
class Boards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId =>
      integer().references(ChildProfiles, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  BoolColumn get isHomeBoard =>
      boolean().withDefault(const Constant(false))();
  IntColumn get gridColumns =>
      integer().withDefault(const Constant(3))();
  IntColumn get gridRows => integer().withDefault(const Constant(3))();
  TextColumn get backgroundColor =>
      text().withDefault(const Constant('#FFFFFF'))();
  // OBF share code if imported/shared
  TextColumn get obfShareCode => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// A single cell in a board grid.
/// CRITICAL: row/col positions are immutable after creation.
/// Motor planning stability depends on this never changing.
class BoardCells extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get boardId => integer().references(Boards, #id)();
  IntColumn get rowIndex => integer()();
  IntColumn get colIndex => integer()();

  // Symbol display
  TextColumn get label => text().withLength(min: 0, max: 200)();
  TextColumn get symbolId => text().nullable()(); // OpenSymbols ID
  TextColumn get symbolUrl => text().nullable()(); // cached remote URL
  TextColumn get customImagePath =>
      text().nullable()(); // local photo from camera/gallery

  // Visual styling
  TextColumn get backgroundColor =>
      text().withDefault(const Constant('#4A90D9'))();
  TextColumn get textColor =>
      text().withDefault(const Constant('#FFFFFF'))();
  IntColumn get fontSize =>
      integer().withDefault(const Constant(16))();

  // Action: speak | navigate | back | clear | backspace
  TextColumn get actionType =>
      text().withDefault(const Constant('speak'))();
  // If different from label (e.g. label="I" but speaks "I")
  TextColumn get speakText => text().nullable()();
  // If actionType = navigate
  IntColumn get targetBoardId => integer().nullable()();

  BoolColumn get isVisible =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Every tap a child makes.
/// Used for on-device word prediction. NEVER leaves the device
/// unless the family explicitly exports their data.
class UsageEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId =>
      integer().references(ChildProfiles, #id)();
  IntColumn get cellId => integer().references(BoardCells, #id)();
  // Denormalized for fast prediction queries
  TextColumn get label => text()();
  DateTimeColumn get tappedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Bigram frequency table for word prediction.
/// Built entirely from UsageEvents, computed on-device.
/// precedingLabel -> followingLabel with frequency count.
class PredictionWeights extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId =>
      integer().references(ChildProfiles, #id)();
  TextColumn get precedingLabel => text()();
  TextColumn get followingLabel => text()();
  IntColumn get frequency =>
      integer().withDefault(const Constant(1))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {childId, precedingLabel, followingLabel}
      ];
}

// ── Database ──────────────────────────────────────────────────

@DriftDatabase(tables: [
  ChildProfiles,
  Boards,
  BoardCells,
  UsageEvents,
  PredictionWeights,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ── Child Profiles ─────────────────────────────────────────

  Future<List<ChildProfile>> getAllProfiles() =>
      select(childProfiles).get();

  Stream<List<ChildProfile>> watchAllProfiles() =>
      select(childProfiles).watch();

  Future<int> insertProfile(ChildProfilesCompanion profile) =>
      into(childProfiles).insert(profile);

  Future<bool> updateProfile(ChildProfile profile) =>
      update(childProfiles).replace(profile);

  // ── Boards ─────────────────────────────────────────────────

  Stream<List<Board>> watchBoardsForChild(int childId) =>
      (select(boards)
            ..where((b) => b.childId.equals(childId)))
          .watch();

  Future<Board?> getHomeBoardForChild(int childId) =>
      (select(boards)
            ..where((b) =>
                b.childId.equals(childId) &
                b.isHomeBoard.equals(true)))
          .getSingleOrNull();

  Future<int> insertBoard(BoardsCompanion board) =>
      into(boards).insert(board);

  // ── Cells ──────────────────────────────────────────────────

  Stream<List<BoardCell>> watchCellsForBoard(int boardId) =>
      (select(boardCells)
            ..where((c) => c.boardId.equals(boardId))
            ..orderBy([
              (c) => OrderingTerm(expression: c.rowIndex),
              (c) => OrderingTerm(expression: c.colIndex),
            ]))
          .watch();

  Future<int> upsertCell(BoardCellsCompanion cell) =>
      into(boardCells).insertOnConflictUpdate(cell);

  Future<void> deleteCell(int cellId) =>
      (delete(boardCells)..where((c) => c.id.equals(cellId))).go();

  // ── Usage & Prediction ─────────────────────────────────────

  Future<void> recordTap(
      int childId, int cellId, String label) async {
    await into(usageEvents).insert(UsageEventsCompanion.insert(
      childId: childId,
      cellId: cellId,
      label: label,
    ));
  }

  /// Get the top N predicted next words given the preceding word.
  Future<List<String>> getPredictions(
    int childId,
    String precedingLabel, {
    int limit = 3,
  }) async {
    final results = await (select(predictionWeights)
          ..where((pw) =>
              pw.childId.equals(childId) &
              pw.precedingLabel.equals(precedingLabel))
          ..orderBy([(pw) => OrderingTerm(
              expression: pw.frequency,
              mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
    return results.map((r) => r.followingLabel).toList();
  }

  /// Call after each tap to train the bigram model.
  Future<void> updatePredictionWeight(
      int childId, String preceding, String following) async {
    await customInsert(
      '''
      INSERT INTO prediction_weights
        (child_id, preceding_label, following_label, frequency)
      VALUES (?, ?, ?, 1)
      ON CONFLICT (child_id, preceding_label, following_label)
      DO UPDATE SET frequency = frequency + 1
      ''',
      variables: [
        Variable.withInt(childId),
        Variable.withString(preceding),
        Variable.withString(following),
      ],
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file =
        File(p.join(dbFolder.path, 'openvoice_aac.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
