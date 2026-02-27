# 🗣️ OpenVoice AAC

**A free, open-source Augmentative and Alternative Communication (AAC) app for children with autism, cerebral palsy, and developmental delays.**

OpenVoice exists because no child should be without a voice due to cost. Every feature is free. Always.

---

## Why OpenVoice?

The leading AAC apps cost $249+. Research shows only **32% of minority families** have access to an AAC device versus 84% of white families. The last widely-used free alternative (Cboard) moved behind a paywall in 2024.

OpenVoice is permanently free, open-source, and built with the AAC community — not just for it.

---

## Core Principles

1. **Offline-first** — works with no internet. Data never waits on a network call.
2. **Motor planning stability** — cells never move. Once a child learns where "more" is, it stays there.
3. **Privacy-safe** — child data never leaves the device unless the family explicitly exports it.
4. **Accessibility within the accessibility app** — switch scanning, high contrast, OpenDyslexic font, adjustable grid sizes.
5. **Built with the community** — SLPs and families involved from day one.

---

## Features (Roadmap)

### v0.1 — MVP (current)
- [ ] Multi-child profiles
- [ ] Customizable symbol boards (3×3 to 5×5)
- [ ] OpenSymbols integration (4000+ free symbols)
- [ ] Native offline TTS (no API key needed)
- [ ] Caregiver edit mode (PIN-gated)
- [ ] On-device word prediction (bigram model)

### v0.2 — Sharing
- [ ] Open Board Format (OBF) import/export
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
| Database | Drift (SQLite) | Offline-first, type-safe |
| State | Riverpod | Predictable, testable |
| TTS | flutter_tts (native) | Free, offline, no API |
| Symbols | OpenSymbols API | Free, open-licensed |
| Cloud sync | Supabase (optional) | Generous free tier |

---

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Dart 3.0+
- Xcode (iOS) or Android Studio (Android)

### Setup

```bash
git clone https://github.com/your-username/openvoice-aac.git
cd openvoice-aac

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
├── main.dart                    # Entry point
├── constants/
│   └── app_theme.dart           # Design system, colors, typography
├── models/
│   └── database.dart            # Drift schema (all data models)
├── services/
│   ├── tts_service.dart         # Text-to-speech wrapper
│   └── symbol_service.dart      # OpenSymbols API + local cache
├── providers/                   # Riverpod state providers
├── screens/
│   ├── home/
│   │   └── profile_selection_screen.dart
│   ├── editor/                  # Caregiver board editor
│   └── settings/                # Profile & app settings
└── widgets/
    ├── grid/
    │   └── communication_grid.dart  # Core AAC grid UI
    ├── symbol/                  # Symbol picker, display
    └── toolbar/                 # Sentence bar, back button
```

---

## Contributing

OpenVoice is built with the AAC community. We especially welcome:
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

OpenVoice is funded by grants and donations. We will never charge families.

If you're an organization that wants to support this work:
- [Donate via Open Collective](#) *(coming soon)*
- Contact us about partnership or grant matching

---

## Acknowledgements

- [OpenAAC](https://www.openaac.org/) for the Open Board Format standard and symbol resources
- [OpenSymbols](https://www.opensymbols.org/) for the free symbol library
- [Cboard](https://www.cboard.io/) for demonstrating what's possible with open-source AAC
- Every SLP and family who gave their time and feedback
