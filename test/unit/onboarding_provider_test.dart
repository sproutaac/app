import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sprout_aac/onboarding/onboarding_provider.dart';

ProviderContainer makeContainer() => ProviderContainer();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AgeRange', () {
    test('has correct labels and grid sizes', () {
      expect(AgeRange.toddler.label, '2–4');
      expect(AgeRange.toddler.defaultGridSize, 3);
      expect(AgeRange.child.label, '5–7');
      expect(AgeRange.child.defaultGridSize, 4);
      expect(AgeRange.older.label, '8–12');
      expect(AgeRange.older.defaultGridSize, 5);
    });
  });

  group('StarterTemplate.forAgeRange', () {
    test('returns littleCommunicator for toddler', () {
      expect(StarterTemplate.forAgeRange(AgeRange.toddler),
          StarterTemplate.littleCommunicator);
    });

    test('returns growingVoice for child', () {
      expect(StarterTemplate.forAgeRange(AgeRange.child),
          StarterTemplate.growingVoice);
    });

    test('returns bigTalker for older', () {
      expect(StarterTemplate.forAgeRange(AgeRange.older),
          StarterTemplate.bigTalker);
    });
  });

  group('OnboardingNotifier', () {
    late ProviderContainer container;
    late OnboardingNotifier notifier;

    setUp(() {
      container = makeContainer();
      notifier = container.read(onboardingProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('initial state has correct defaults', () {
      final state = container.read(onboardingProvider);
      expect(state.childName, '');
      expect(state.ageRange, isNull);
      expect(state.accessMethod, isNull);
      expect(state.selectedTemplate, isNull);
      expect(state.favoriteSymbols, isEmpty);
      expect(state.isComplete, isFalse);
    });

    test('setChildName trims and updates name', () {
      notifier.setChildName('  Alex  ');
      expect(container.read(onboardingProvider).childName, 'Alex');
    });

    test('setAgeRange updates age and auto-selects template', () {
      notifier.setAgeRange(AgeRange.child);
      final state = container.read(onboardingProvider);
      expect(state.ageRange, AgeRange.child);
      expect(state.selectedTemplate, StarterTemplate.growingVoice);
    });

    test('setAgeRange for each value auto-selects correct template', () {
      for (final age in AgeRange.values) {
        notifier.setAgeRange(age);
        final state = container.read(onboardingProvider);
        expect(state.selectedTemplate, StarterTemplate.forAgeRange(age));
      }
    });

    test('setAccessMethod updates access method', () {
      for (final method in AccessMethod.values) {
        notifier.setAccessMethod(method);
        expect(container.read(onboardingProvider).accessMethod, method);
      }
    });

    test('setTemplate overrides auto-selected template', () {
      notifier.setAgeRange(AgeRange.toddler);
      notifier.setTemplate(StarterTemplate.bigTalker);
      expect(container.read(onboardingProvider).selectedTemplate,
          StarterTemplate.bigTalker);
    });

    test('addFavoriteSymbol adds up to 3 unique symbols', () {
      notifier.addFavoriteSymbol('a');
      notifier.addFavoriteSymbol('b');
      notifier.addFavoriteSymbol('c');
      expect(container.read(onboardingProvider).favoriteSymbols,
          ['a', 'b', 'c']);
    });

    test('addFavoriteSymbol ignores duplicates', () {
      notifier.addFavoriteSymbol('a');
      notifier.addFavoriteSymbol('a');
      expect(container.read(onboardingProvider).favoriteSymbols, ['a']);
    });

    test('addFavoriteSymbol stops at 3', () {
      notifier.addFavoriteSymbol('a');
      notifier.addFavoriteSymbol('b');
      notifier.addFavoriteSymbol('c');
      notifier.addFavoriteSymbol('d'); // ignored
      expect(container.read(onboardingProvider).favoriteSymbols.length, 3);
    });

    test('removeFavoriteSymbol removes the correct id', () {
      notifier.addFavoriteSymbol('a');
      notifier.addFavoriteSymbol('b');
      notifier.removeFavoriteSymbol('a');
      expect(container.read(onboardingProvider).favoriteSymbols, ['b']);
    });

    test('complete() sets isComplete and persists to SharedPreferences',
        () async {
      await notifier.complete();
      final state = container.read(onboardingProvider);
      expect(state.isComplete, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_complete'), isTrue);
    });

    test('onboardingCompleteProvider reads false when not set', () async {
      final result =
          await container.read(onboardingCompleteProvider.future);
      expect(result, isFalse);
    });

    test('onboardingCompleteProvider reads true after complete()', () async {
      await notifier.complete();
      // Invalidate so it re-reads SharedPreferences
      container.invalidate(onboardingCompleteProvider);
      final result =
          await container.read(onboardingCompleteProvider.future);
      expect(result, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      const state = OnboardingState(
        childName: 'Sam',
        ageRange: AgeRange.child,
        favoriteSymbols: ['x'],
      );
      final copy = state.copyWith(childName: 'Jo');
      expect(copy.childName, 'Jo');
      expect(copy.ageRange, AgeRange.child);
      expect(copy.favoriteSymbols, ['x']);
    });
  });
}
