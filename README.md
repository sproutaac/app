# 🌱 SproutAAC

**A free, open-source Augmentative and Alternative Communication (AAC) app for children with autism, cerebral palsy, and developmental delays.**

Sprout exists because no child should be without a voice due to cost. Every feature is free. Always.

> **Status: pre-release — not yet on the App Store or Google Play.** We're building in public and the code runs, but the app isn't downloadable yet. [Join the waitlist](https://sproutaac.org) to be notified on launch.

---

## Why Sprout?

The leading AAC apps cost $249+. Research shows only **32% of minority families** have access to an AAC device versus 84% of white families. The last widely-used free alternative (Cboard) moved behind a paywall in 2024.

Sprout is permanently free, open-source, and built with the AAC community — not just for it.

---

## Core Principles

1. **Offline-first** — works with no internet. Data never waits on a network call.
2. **Motor planning stability** — cells never move. Once a child learns where "more" is, it stays there.
3. **Privacy-safe** — child data never leaves the device unless the family explicitly exports it.
4. **Accessibility within the accessibility app** — switch scanning, high contrast, OpenDyslexic font, adjustable grid sizes.
5. **Built with the community** — SLPs and families involved from day one.

---

## Features

### v0.1 — MVP (current)
- [x] Guided 5-step onboarding flow
- [x] Three starter boards: Little Communicator (3×3), Growing Voice (4×4), Big Talker (5×5)
- [x] Open Board Format (OBF) templates with Fitzgerald Key color coding
- [x] ARASAAC symbol search — 30,000+ free pictograms, no account needed
- [x] Communication screen with sentence bar and native offline TTS
- [x] On-device word prediction (bigram model, trains silently from every tap)
- [x] Multi-child profiles
- [x] Caregiver edit mode — PIN-gated board editor (add, edit, delete cells)

### v0.2 — Sharing
- [ ] OBF import/export
- [ ] Board sharing via share code
- [ ] SLP → family board push

### v0.3 — Access
- [ ] Switch scanning (single & dual switch) — scaffolded in v0.1
- [ ] Eye gaze support
- [ ] Larger grid sizes (42, 84 cells)

### v0.4 — Community
- [ ] Optional cloud backup (Supabase)
- [ ] Therapist dashboard
- [ ] Community board library

---

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Framework | Flutter | Single codebase, iOS + Android |
| Database | Drift (SQLite) | Offline-first, type-safe, generated queries |
| State | Riverpod | Predictable, testable, no BuildContext leaks |
| TTS | flutter_tts (native) | Free, offline, no API key |
| Symbols | ARASAAC API | Free, no auth, CC BY-NC-SA, 30k+ pictograms |
| Cloud sync | Supabase (optional) | Generous free tier, additive only |

---

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Dart 3.0+
- Xcode + CocoaPods (iOS)  or Android Studio (Android)

### Setup

```bash
git clone https://github.com/sproutaac/app.git
cd app

# Install dependencies
flutter pub get

# Generate Drift database code
dart run build_runner build

# Run on iOS simulator
flutter run -d "iPhone 17 Pro"

# Run on Android emulator
flutter run -d emulator-5554
```

---

## Project Structure

```
lib/
├── main.dart                        # Entry point, ProviderScope, OnboardingGate
├── constants/
│   └── app_theme.dart               # Design system, Fitzgerald Key colors
├── models/
│   └── database.dart                # Drift schema (profiles, boards, cells, usage, prediction)
├── onboarding/
│   ├── onboarding_flow.dart         # OnboardingGate + OnboardingFlow (PageView)
│   ├── onboarding_provider.dart     # State: name, age, template, access method
│   ├── onboarding_widgets.dart      # Shared step UI components
│   └── steps/
│       ├── step_welcome.dart        # Green gradient splash
│       ├── step_profile.dart        # Name + age range + access method
│       ├── step_template.dart       # Starter board picker with mini grid preview
│       ├── step_personalize.dart    # Favorite symbol search
│       └── step_done.dart           # Creates profile + board + cells in DB
├── services/
│   ├── tts_service.dart             # flutter_tts wrapper, per-child voice settings
│   └── symbol_service.dart          # ARASAAC API + local disk cache
├── screens/
│   ├── home/
│   │   └── profile_selection_screen.dart  # Who's communicating today?
│   ├── communication/
│   │   └── communication_screen.dart      # Main board view, sentence bar, prediction strip
│   └── editor/
│       ├── editor_screen.dart             # PIN gate + editable board grid
│       └── cell_editor_sheet.dart         # Add/edit/delete a single cell
└── widgets/
    ├── grid/
    │   └── communication_grid.dart  # AAC grid, switch scanning, tap animation
    └── symbol/
        └── symbol_picker.dart       # Reusable symbol search widget (onboarding + editor)
assets/
└── templates/
    ├── little_communicator.json     # OBF 3×3 starter board (ages 2–4)
    ├── growing_voice.json           # OBF 4×4 starter board (ages 4–7)
    └── big_talker.json              # OBF 5×5 starter board (ages 7+)
```

---

## Testing

**124 tests · all passing**

Run the full suite:

```bash
flutter test
```

Run with coverage:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

### Strategy

| Layer | Tool | Location |
|---|---|---|
| Unit — models, services, state | `flutter_test` + `mocktail` | `test/unit/` |
| Widget — screens and widgets | `flutter_test` + `mocktail` | `test/widget/` |
| App smoke test | `flutter_test` | `test/widget_test.dart` |

**Unit tests** exercise logic in isolation with no Flutter rendering:
- `database_test.dart` — all Drift queries (profiles, boards, cells, usage, prediction) against an in-memory SQLite database
- `symbol_service_test.dart` — ARASAAC API, disk cache, offline fallback; Dio is mocked
- `onboarding_provider_test.dart` — `OnboardingNotifier` state transitions, `AgeRange`, `StarterTemplate`
- `aac_symbol_test.dart` — `AacSymbol` JSON serialisation and `fromArasaacJson` parsing

**Widget tests** render complete screens in a headless Flutter environment with Riverpod providers overridden by in-memory fakes:
- `profile_selection_test.dart` — empty state, profile cards, quick-add dialog
- `communication_screen_test.dart` — sentence bar, speak/backspace/clear cells, speak-all, no-board/empty-board placeholders
- `communication_grid_test.dart` — tap actions (speak, navigate, backspace, clear), invisible cells
- `editor_test.dart` — new/edit cell, save, delete confirmation, action type switching
- `symbol_picker_test.dart` — search states: spinner, no results, results, selection, offline error
- `onboarding_test.dart` — `OnboardingGate` gating logic (complete, not complete, error, loading)
- `onboarding_steps_test.dart` — all five onboarding steps + shared UI components (`OnboardingStepShell`, `OnboardingHeading`, `OnboardingContinueButton`); covers `step_profile`, `step_template`, `step_personalize`, `step_done`, `onboarding_widgets`

**Notable decisions:**
- Drift databases are created with `AppDatabase.forTesting(NativeDatabase.memory())` so every test gets a fresh, isolated schema.
- `TtsService` and `SymbolService` are replaced with `mocktail` mocks; no network calls are made during tests.
- `FlutterSecureStorage` is mocked via `TestDefaultBinaryMessengerBinding.setMockMethodCallHandler` in `test/helpers/test_helpers.dart`.
- Widgets with `AnimationController` use `pump(Duration)` instead of `pumpAndSettle()` to avoid timeouts.
- `StepProfile` uses `tester.binding.setSurfaceSize(const Size(800, 1100))` to prevent layout overflow in the default test viewport.
- The EditorScreen PIN dialog cannot be widget-tested in isolation because the screen uses a `static const FlutterSecureStorage` field (no injection point). PIN UX is covered by manual / integration testing.

---

## Contributing

Sprout is built with the AAC community. We especially welcome:
- **SLPs** — clinical expertise on vocabulary, motor planning, and board design
- **AAC users and families** — lived experience that no spec can replace
- **Developers** — Flutter, accessibility, offline-first architecture
- **Translators** — AAC must be accessible across languages

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

Join the conversation: [OpenAAC Discord](https://discord.gg/TEH8uxh)

---

## License

GPL v3 — free to use, fork, and build upon. Any app built on Sprout must also be open source. See [LICENSE](LICENSE).

---

## Funding

Sprout is funded by grants and donations. We will never charge families.

If you're an organization that wants to support this work, email [hello@sproutaac.org](mailto:hello@sproutaac.org). Donation links coming once we launch.

---

## Acknowledgements

- [OpenAAC](https://www.openaac.org/) for the Open Board Format standard
- [ARASAAC](https://arasaac.org/) for the free pictogram library (CC BY-NC-SA 4.0)
- [Cboard](https://www.cboard.io/) for demonstrating what's possible with open-source AAC
- Every SLP and family who gave their time and feedback
