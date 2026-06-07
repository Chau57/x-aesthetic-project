# X-Aesthetic Mobile App

Interactive photography assistant built with Flutter. The app guides users while shooting, analyzes photos after capture, and tracks learning progress over time.

**Version:** `0.2.0+2`

## Current Status

The MVP foundation is in place:

- **Working:** Camera (preview, HDR, horizon, exposure), photo review with rule-based scoring, app gallery, progress dashboard, plugin infrastructure (contract only).
- **Pending:** Production aesthetic plugins, TFLite inference, Hive learning log, live AI guidance overlays.

See [docs/current-state.md](docs/current-state.md) for a detailed implemented vs planned breakdown. Track checklist progress in [TODO.md](TODO.md).

## Folder Structure

```text
lib/
├── app/                  # Bootstrap, shell, global controller
├── core/
│   ├── ai/               # Shared AI output models (DTOs)
│   ├── camera/           # Camera frame and pose abstractions
│   ├── common/           # Result and exception helpers
│   └── plugin/           # Microkernel plugin contract and manager
├── domain/               # Business entities and future repository contracts
├── data/                 # AppGalleryStore (JSON + local files)
├── services/
│   ├── camera/           # HDR, aspect ratio, hardware bridge
│   ├── analysis/         # Rule-based photo evaluator
│   └── ai/               # AiEngine interface (no implementation yet)
└── presentation/         # Camera, gallery, photo review, dashboard UI

assets/
├── models/               # TFLite models (placeholder)
└── style_configs/        # Reference style profiles (sample JSON)
```

## App Flow

```text
Camera tab → capture → PhotoReview overlay → save to library
                ↓
Gallery tab ← stored photos with evaluations
                ↓
Dashboard tab ← progress stats from saved data
```

Main screens: `CameraScreen`, `PhotoReviewScreen`, `GalleryScreen`, `DashboardScreen`.

> `PreviewScreen` exists as a legacy stub and is **not** wired into navigation.

## Documentation

| Doc | Description |
|-----|-------------|
| [Getting started](docs/getting-started.md) | Setup, permissions, first run, troubleshooting |
| [Current state vs roadmap](docs/current-state.md) | What works today vs planned |
| [Project roadmap](TODO.md) | Phased checklist — source of truth for progress |
| [Architecture](docs/architecture.md) | Layers, dependency rules, runtime flows |
| [Target system diagram](docs/diagrams/system_architecture.mmd) | Planned ML / plugin pipeline (north star) |
| [Plugin contract](docs/plugin_contract.md) | How to add aesthetic guidance plugins |
| [UI design mockups](docs/ui-design.md) | Screen references and design flows |
| [Data & persistence](docs/data-and-persistence.md) | Gallery store, metadata schema |
| [Contributing](docs/contributing.md) | Git workflow, quality gates, conventions |

## Run

Prerequisites and platform setup: [docs/getting-started.md](docs/getting-started.md).

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```
