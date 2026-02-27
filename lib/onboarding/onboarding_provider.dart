import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Onboarding State ────────────────────────────────────────────────────────

enum AgeRange {
  toddler('2–4', '2-4', 3),
  child('5–7', '4-7', 4),
  older('8–12', '7+', 5);

  const AgeRange(this.label, this.templateAgeKey, this.defaultGridSize);
  final String label;
  final String templateAgeKey;
  final int defaultGridSize;
}

enum AccessMethod { touch, switchAccess, eyeGaze, setupLater }

enum StarterTemplate {
  littleCommunicator(
    id: 'little_communicator',
    name: 'Little Communicator',
    subtitle: 'Simple 9-word board',
    description: 'The most important words, in positions that stick.',
    gridSize: '3×3',
    wordCount: 9,
    ageRange: AgeRange.toddler,
    previewWords: ['more', 'stop', 'help', 'want', 'go', 'eat', 'drink', 'yes', 'no'],
    assetPath: 'assets/templates/little_communicator.json',
  ),
  growingVoice(
    id: 'growing_voice',
    name: 'Growing Voice',
    subtitle: 'Building 16-word board',
    description: 'Adds pronouns and action words for early sentences.',
    gridSize: '4×4',
    wordCount: 16,
    ageRange: AgeRange.child,
    previewWords: ['I', 'more', 'stop', 'help', 'want', 'like', 'go', 'eat', "don't", 'have', 'that', 'drink', 'play', 'all done', 'yes', 'no'],
    assetPath: 'assets/templates/growing_voice.json',
  ),
  bigTalker(
    id: 'big_talker',
    name: 'Big Talker',
    subtitle: 'Expressive 25-word board',
    description: 'Full core vocabulary for multi-word sentences.',
    gridSize: '5×5',
    wordCount: 25,
    ageRange: AgeRange.older,
    previewWords: ['I', 'you', 'we', 'they', 'help', 'want', 'like', 'feel', 'go', 'stop', 'have', "don't", 'that', 'put', 'more', 'good', 'bad', 'big', 'little', 'where', 'eat', 'drink', 'play', 'yes', 'no'],
    assetPath: 'assets/templates/big_talker.json',
  );

  const StarterTemplate({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.gridSize,
    required this.wordCount,
    required this.ageRange,
    required this.previewWords,
    required this.assetPath,
  });

  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String gridSize;
  final int wordCount;
  final AgeRange ageRange;
  final List<String> previewWords;
  final String assetPath;

  static StarterTemplate forAgeRange(AgeRange age) {
    return values.firstWhere(
      (t) => t.ageRange == age,
      orElse: () => littleCommunicator,
    );
  }
}

class OnboardingState {
  final String childName;
  final AgeRange? ageRange;
  final AccessMethod? accessMethod;
  final StarterTemplate? selectedTemplate;
  final List<String> favoriteSymbols; // up to 3 symbol IDs from search
  final bool isComplete;

  const OnboardingState({
    this.childName = '',
    this.ageRange,
    this.accessMethod,
    this.selectedTemplate,
    this.favoriteSymbols = const [],
    this.isComplete = false,
  });

  OnboardingState copyWith({
    String? childName,
    AgeRange? ageRange,
    AccessMethod? accessMethod,
    StarterTemplate? selectedTemplate,
    List<String>? favoriteSymbols,
    bool? isComplete,
  }) {
    return OnboardingState(
      childName: childName ?? this.childName,
      ageRange: ageRange ?? this.ageRange,
      accessMethod: accessMethod ?? this.accessMethod,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      favoriteSymbols: favoriteSymbols ?? this.favoriteSymbols,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

// ─── Onboarding Notifier ─────────────────────────────────────────────────────

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void setChildName(String name) => state = state.copyWith(childName: name.trim());

  void setAgeRange(AgeRange age) {
    // Auto-select the template for this age range, but allow override
    final template = StarterTemplate.forAgeRange(age);
    state = state.copyWith(ageRange: age, selectedTemplate: template);
  }

  void setAccessMethod(AccessMethod method) =>
      state = state.copyWith(accessMethod: method);

  void setTemplate(StarterTemplate template) =>
      state = state.copyWith(selectedTemplate: template);

  void addFavoriteSymbol(String symbolId) {
    if (state.favoriteSymbols.length < 3 &&
        !state.favoriteSymbols.contains(symbolId)) {
      state = state.copyWith(
        favoriteSymbols: [...state.favoriteSymbols, symbolId],
      );
    }
  }

  void removeFavoriteSymbol(String symbolId) {
    state = state.copyWith(
      favoriteSymbols: state.favoriteSymbols.where((s) => s != symbolId).toList(),
    );
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    state = state.copyWith(isComplete: true);
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);

/// Whether the user has completed onboarding before.
/// Read once on app start — if false, show onboarding flow.
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
});
