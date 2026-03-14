import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sprout_aac/models/database.dart';
import 'package:sprout_aac/screens/communication/communication_screen.dart';

import '../helpers/test_helpers.dart';

Widget _wrap({
  required ChildProfile profile,
  required AppDatabase db,
  required MockTtsService tts,
  required MockSymbolService symbols,
}) =>
    ProviderScope(
      overrides: allOverrides(db: db, symbols: symbols, tts: tts),
      child: MaterialApp(
        home: CommunicationScreen(profile: profile),
      ),
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
  late MockTtsService tts;
  late MockSymbolService symbols;
  late ChildProfile profile;

  setUp(() async {
    db = makeTestDb();
    tts = MockTtsService();
    symbols = MockSymbolService();
    stubTtsService(tts);
    stubSymbolService(symbols);

    final pid = await db.insertProfile(ChildProfilesCompanion.insert(
      name: 'Alex',
      gridColumns: const Value(3),
      gridRows: const Value(3),
    ));
    final profiles = await db.getAllProfiles();
    profile = profiles.first;

    final bid = await db.insertBoard(BoardsCompanion.insert(
      childId: pid,
      name: 'Home',
      isHomeBoard: const Value(true),
      gridColumns: const Value(3),
      gridRows: const Value(3),
    ));

    // Insert a 'speak' cell
    await db.upsertCell(BoardCellsCompanion.insert(
      boardId: bid,
      rowIndex: 0,
      colIndex: 0,
      label: 'more',
      actionType: const Value('speak'),
    ));
    // Insert a 'backspace' cell
    await db.upsertCell(BoardCellsCompanion.insert(
      boardId: bid,
      rowIndex: 0,
      colIndex: 1,
      label: '⌫',
      actionType: const Value('backspace'),
    ));
    // Insert a 'clear' cell
    await db.upsertCell(BoardCellsCompanion.insert(
      boardId: bid,
      rowIndex: 0,
      colIndex: 2,
      label: 'clear',
      actionType: const Value('clear'),
    ));
  });

  tearDown(() => db.close());

  testWidgets('renders sentence bar placeholder when empty', (tester) async {
    await tester.pumpWidget(
        _wrap(profile: profile, db: db, tts: tts, symbols: symbols));
    await tester.pumpAndSettle();

    expect(find.text('Tap symbols to build a sentence'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('tapping a speak cell adds word to sentence bar',
      (tester) async {
    await tester.pumpWidget(
        _wrap(profile: profile, db: db, tts: tts, symbols: symbols));
    await tester.pumpAndSettle();

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();

    expect(find.text('more'), findsWidgets); // in both grid and sentence bar
    verify(() => tts.speak('more')).called(1);

    await _driftFlush(tester);
  });

  testWidgets('backspace cell removes last word', (tester) async {
    await tester.pumpWidget(
        _wrap(profile: profile, db: db, tts: tts, symbols: symbols));
    await tester.pumpAndSettle();

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('⌫'));
    await tester.pumpAndSettle();

    expect(find.text('Tap symbols to build a sentence'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('backspace on empty sentence bar is a no-op', (tester) async {
    await tester.pumpWidget(
        _wrap(profile: profile, db: db, tts: tts, symbols: symbols));
    await tester.pumpAndSettle();

    // Tap backspace with no words
    await tester.tap(find.text('⌫'));
    await tester.pumpAndSettle();

    expect(find.text('Tap symbols to build a sentence'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('clear cell empties the sentence bar', (tester) async {
    await tester.pumpWidget(
        _wrap(profile: profile, db: db, tts: tts, symbols: symbols));
    await tester.pumpAndSettle();

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('clear'));
    await tester.pumpAndSettle();

    expect(find.text('Tap symbols to build a sentence'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('sentence bar backspace button removes last word', (tester) async {
    await tester.pumpWidget(
        _wrap(profile: profile, db: db, tts: tts, symbols: symbols));
    await tester.pumpAndSettle();

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();

    // Backspace icon button in the sentence bar
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Tap symbols to build a sentence'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('speak-all button in sentence bar triggers TTS', (tester) async {
    await tester.pumpWidget(
        _wrap(profile: profile, db: db, tts: tts, symbols: symbols));
    await tester.pumpAndSettle();

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pumpAndSettle();

    verify(() => tts.speak(any())).called(greaterThanOrEqualTo(1));

    await _driftFlush(tester);
  });

  testWidgets('sentence bar speak on tap triggers TTS', (tester) async {
    await tester.pumpWidget(
        _wrap(profile: profile, db: db, tts: tts, symbols: symbols));
    await tester.pumpAndSettle();

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();

    // Tap the sentence bar container
    await tester.tap(find.text('more').last);
    await tester.pumpAndSettle();

    verify(() => tts.speak(any())).called(greaterThanOrEqualTo(1));

    await _driftFlush(tester);
  });

  testWidgets('clear button in sentence bar empties sentence', (tester) async {
    await tester.pumpWidget(
        _wrap(profile: profile, db: db, tts: tts, symbols: symbols));
    await tester.pumpAndSettle();

    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();

    // Sentence bar clear
    await tester.tap(find.text('clear'));
    await tester.pumpAndSettle();

    expect(find.text('Tap symbols to build a sentence'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('shows no-board placeholder when no board exists',
      (tester) async {
    await db.insertProfile(ChildProfilesCompanion.insert(
      name: 'NoBoard',
    ));
    final profiles = await db.getAllProfiles();
    final profileNoBoard = profiles.firstWhere((p) => p.name == 'NoBoard');

    await tester.pumpWidget(
        _wrap(profile: profileNoBoard, db: db, tts: tts, symbols: symbols));
    await tester.pumpAndSettle();

    expect(find.text('No board set up yet'), findsOneWidget);

    await _driftFlush(tester);
  });

  testWidgets('shows empty-board placeholder when board has no cells',
      (tester) async {
    final pid2 = await db.insertProfile(ChildProfilesCompanion.insert(
      name: 'EmptyBoard',
    ));
    await db.insertBoard(BoardsCompanion.insert(
      childId: pid2,
      name: 'Home',
      isHomeBoard: const Value(true),
    ));
    final profiles = await db.getAllProfiles();
    final profileEmpty = profiles.firstWhere((p) => p.name == 'EmptyBoard');

    await tester.pumpWidget(
        _wrap(profile: profileEmpty, db: db, tts: tts, symbols: symbols));
    await tester.pumpAndSettle();

    expect(find.textContaining("board has no symbols yet"), findsOneWidget);

    await _driftFlush(tester);
  });
}
