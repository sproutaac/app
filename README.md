# 🌱 Sprout AAC

**A free, open-source Augmentative and Alternative Communication (AAC) app for children with autism, cerebral palsy, and developmental delays.**

Sprout exists because no child should be without a voice due to cost. Every feature is free. Always.

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
- [x] Guided onboarding flow (5-step setup wizard)
- [x] Three starter boards: Little Communicator (3×3), Growing Voice (4×4), Big Talker (5×5)
- [x] Open Board Format (OBF) templates with Fitzgerald Key color coding
- [x] Communication screen with sentence bar and native offline TTS
- [x] Multi-child profiles
- [ ] OpenSymbols integration (4,000+ free symbols — API stub ready)
- [ ] Caregiver edit mode (PIN-gated board editor)
- [ ] On-device word prediction (bigram model — schema + DB methods ready)

### v0.2 — Sharing
- [ ] OBF import/export (stubs in place)
- [ ] Board sharing via share code
- [ ] SLP → family board push

### v0.3 — Access
- [ ] Switch scanning (single & dual switch)
- [ ] Eye gaze support
- [ ] Larger grid sizes (42, 84 cells)

### v0.4 — Community
- [ ] Optional cloud backup (Supabase)
- [ ] Therapist dashboard
- [ ] Board library (community-contributed boards)

---

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Framework | Flutter | Single codebase, iOS + Android |
| Database | Drift (SQLite) | Offline-first, type-safe, generated queries |
| State | Riverpod | Predictable, testable, no BuildContext leaks |
| TTS | flutter_tts (native) | Free, offline, no API key |
| Symbols | OpenSymbols API | Free, open-licensed, 4k+ symbols |
| Onboarding | SharedPreferences | Lightweight, no extra infrastructure |
| Cloud sync | Supabase (optional) | Generous free tier, additive only |

---

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Dart 3.0+
- Xcode (iOS) or Android Studio (Android)

### Setup

```bash
git clone https://github.com/sproutaac/app.git
cd app

# Install dependencies
flutter pub get

# Generate Drift database code
dart run build_runner build

# Run on device/simulator
flutter run
```

---

## Project Structure

```
lib/
├── main.dart                        # Entry point, ProviderScope, OnboardingGate
├── constants/
│   └── app_theme.dart               # Design system, Fitzgerald Key colors
├── models/
│   └── database.dart                # Drift schema (profiles, boards, cells, usage)
├── onboarding/
│   ├── onboarding.dart              # Library barrel + integration guide
│   ├── onboarding_flow.dart         # OnboardingGate + OnboardingFlow (PageView)
│   ├── onboarding_provider.dart     # State: name, age, template, access method
│   ├── onboarding_widgets.dart      # Shared step UI components
│   └── steps/
│       ├── step_welcome.dart        # Green gradient splash
│       ├── step_profile.dart        # Name + age range + access method
│       ├── step_template.dart       # Starter board picker with mini grid preview
│       ├── step_personalize.dart    # Favorite symbol search (OpenSymbols stub)
│       └── step_done.dart           # Creates profile + board in DB, marks complete
├── services/
│   ├── tts_service.dart             # flutter_tts wrapper, per-child voice settings
│   └── symbol_service.dart          # OpenSymbols API + local cache
├── screens/
│   ├── home/
│   │   └── profile_selection_screen.dart  # Who's communicating today?
│   └── communication/
│       └── communication_screen.dart      # Main board view + sentence bar
└── widgets/
    └── grid/
        └── communication_grid.dart  # AAC grid, switch scanning, tap animation
assets/
└── templates/
    ├── little_communicator.json     # OBF 3×3 starter board (ages 2–4)
    ├── growing_voice.json           # OBF 4×4 starter board (ages 4–7)
    └── big_talker.json              # OBF 5×5 starter board (ages 7+)
```

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

MIT License — free to use, fork, and build upon. See [LICENSE](LICENSE).

---

## Funding

Sprout is funded by grants and donations. We will never charge families.

If you're an organization that wants to support this work:
- [Donate via Open Collective](#) *(coming soon)*
- Contact us about partnership or grant matching

---

## Acknowledgements

- [OpenAAC](https://www.openaac.org/) for the Open Board Format standard and symbol resources
- [OpenSymbols](https://www.opensymbols.org/) for the free symbol library
- [Cboard](https://www.cboard.io/) for demonstrating what's possible with open-source AAC
- Every SLP and family who gave their time and feedback
