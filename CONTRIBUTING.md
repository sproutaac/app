# Contributing to Sprout AAC

Thank you for helping give children a voice. This document covers how to contribute effectively — whether you're a developer, SLP, AAC user, family member, or translator.

---

## Ways to Contribute

### Not a developer? Still valuable.
- **SLPs and AAC specialists** — open an issue to flag vocabulary gaps, incorrect Fitzgerald Key usage, motor planning concerns, or clinical accuracy problems. Label it `clinical`.
- **AAC users and families** — file issues for anything that feels wrong in actual use. Your lived experience is the most important feedback we get. Label it `user-feedback`.
- **Translators** — see [Localization](#localization) below.

### Developers
- Bug fixes, new features, accessibility improvements, performance work — all welcome.
- Check the [open issues](https://github.com/sproutaac/app/issues) and look for `good first issue` labels.

---

## Before You Start

1. **Open an issue first** for anything non-trivial. Describe what you want to change and why. This prevents duplicate work and makes sure your PR gets merged.
2. **For clinical changes** (vocabulary, symbol placement, color coding) — tag an SLP reviewer. We don't ship AAC design decisions without clinical input.

---

## Dev Setup

```bash
git clone https://github.com/sproutaac/app.git
cd app

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Requirements: Flutter 3.0+, Dart 3.0+, Xcode (iOS) or Android Studio (Android).

---

## The Three Rules

Every change must pass these before it ships:

1. **Offline-first** — nothing in your change should require a network connection to function. If you're adding a network feature, it must degrade gracefully when offline.

2. **Motor planning stability** — cell positions (`rowIndex`, `colIndex`) are immutable after creation. Do not write code that moves, reorders, or shuffles existing cells. A child's muscle memory is not a bug to fix.

3. **Privacy-safe** — child data stays on device unless the family explicitly exports it. Don't add any analytics, crash reporters, or telemetry that touches child usage data.

---

## Code Style

- Follow standard [Flutter style guidelines](https://docs.flutter.dev/development/tools/formatting).
- Run `flutter analyze` before opening a PR. Zero warnings is the target.
- Riverpod providers live in their relevant feature directory, not a global `providers/` folder.
- Drift queries go in `AppDatabase` methods in `models/database.dart` — not scattered across widgets.
- Keep child-facing UI (`CommunicationScreen`, `CommunicationGrid`) completely separate from caregiver UI (edit mode, settings). No edit affordances should ever be visible in communication mode.

---

## Pull Requests

- Keep PRs focused. One logical change per PR.
- Write a clear description: what changed, why, and how to test it.
- If your change affects the communication grid or cell behavior, include a note about how you tested motor planning stability (e.g. "cells don't shift on hot reload / profile switch").
- Screenshots or screen recordings are very helpful for UI changes.

---

## Tests

Test coverage is minimal right now — the project is pre-launch and moving fast. We'd especially love help adding tests for:

- Grid behaviour and cell rendering (critical: motor planning stability must never regress)
- `AppDatabase` query methods in `models/database.dart`
- TTS service edge cases (empty sentence bar, rapid taps)

When adding tests, use the standard `flutter_test` package. Run the suite with:

```bash
~/development/bin/flutter test
```

If you're not sure where to start, opening an issue tagged `testing` to discuss scope is very welcome.

---

## Localization

AAC must work across languages. If you want to add a language:
1. Open an issue tagged `localization` to coordinate (another translator may already be working on it).
2. We use Flutter's standard `intl` / ARB approach — localization strings live in `lib/l10n/`.
3. Starter board vocabulary needs clinical review in each language — just translating words isn't enough. Please loop in a native-speaking SLP if possible.

---

## Reporting Issues

When filing a bug:
- Include device type, OS version, and Flutter version if relevant.
- For clinical/vocabulary issues, describe the specific concern and cite a source if you have one.
- For crashes, include the stack trace from `flutter logs`.

---

## Code of Conduct

Be kind. This project exists to serve children and families in genuinely difficult situations. Treat every contributor — developer, clinician, or parent — with respect.

Harassment of any kind is not tolerated and will result in immediate removal from the project.
