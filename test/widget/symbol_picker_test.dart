import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sprout_aac/services/symbol_service.dart';
import 'package:sprout_aac/widgets/symbol/symbol_picker.dart';

import '../helpers/test_helpers.dart';

Widget _wrap(Widget child, MockSymbolService svc) {
  return ProviderScope(
    overrides: [symbolServiceProvider.overrideWithValue(svc)],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  late MockSymbolService svc;

  setUp(() {
    svc = MockSymbolService();
    stubSymbolService(svc);
  });

  testWidgets('shows search field initially', (tester) async {
    await tester.pumpWidget(_wrap(
      SymbolPicker(onSelected: (_) {}),
      svc,
    ));

    expect(find.byType(TextField), findsOneWidget);
    // Flutter renders hintText as a Text widget — find.text() matches it
    expect(find.text('Search symbols (e.g. "dog", "swimming")'),
        findsOneWidget);
  });

  testWidgets('shows spinner while searching', (tester) async {
    // Never resolves during this test
    when(() => svc.search(any()))
        .thenAnswer((_) => Future.delayed(const Duration(seconds: 10)));

    await tester.pumpWidget(_wrap(
      SymbolPicker(onSelected: (_) {}),
      svc,
    ));

    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows "No symbols found" when results are empty',
      (tester) async {
    when(() => svc.search(any())).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(
      SymbolPicker(onSelected: (_) {}),
      svc,
    ));

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.textContaining('No symbols found'), findsOneWidget);
  });

  testWidgets('shows results and calls onSelected on tap', (tester) async {
    const sym = AacSymbol(
      id: '1',
      label: 'cat',
      imageUrl: 'https://static.arasaac.org/pictograms/1/1_500.png',
      source: 'arasaac',
    );
    when(() => svc.search('cat')).thenAnswer((_) async => [sym]);

    SymbolResult? selected;
    await tester.pumpWidget(_wrap(
      SymbolPicker(onSelected: (r) => selected = r),
      svc,
    ));

    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pumpAndSettle();

    // Tap the result tile label (not the text typed in the TextField)
    await tester.tap(find.text('cat').last);
    await tester.pump();

    expect(selected, isNotNull);
    expect(selected!.id, '1');
    expect(selected!.label, 'cat');
    // Field should be cleared after selection
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows checkmark for already-selected symbol', (tester) async {
    const sym = AacSymbol(
      id: '1',
      label: 'cat',
      imageUrl: 'https://static.arasaac.org/pictograms/1/1_500.png',
      source: 'arasaac',
    );
    when(() => svc.search('cat')).thenAnswer((_) async => [sym]);

    await tester.pumpWidget(_wrap(
      SymbolPicker(
        selectedIds: const {'1'},
        onSelected: (_) {},
      ),
      svc,
    ));

    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('clear button clears query', (tester) async {
    when(() => svc.search('cat')).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(
      SymbolPicker(onSelected: (_) {}),
      svc,
    ));

    await tester.enterText(find.byType(TextField), 'cat');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    // Results section disappears when query is empty
    expect(find.textContaining('No symbols found'), findsNothing);
  });

  testWidgets('shows error message when search throws', (tester) async {
    when(() => svc.search(any())).thenThrow(Exception('offline'));

    await tester.pumpWidget(_wrap(
      SymbolPicker(onSelected: (_) {}),
      svc,
    ));

    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pumpAndSettle();

    expect(find.textContaining('Search unavailable offline'), findsOneWidget);
  });
}
