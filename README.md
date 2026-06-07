# X-Aesthetic Mobile App

Interactive photography assistant built with Flutter. The app guides users while shooting, analyzes photos after capture, and tracks learning progress over time.

**Version:** `0.2.0+2`

## Current Status

The repo currently contains a functional Flutter MVP foundation.

**Working:**

- App shell with Camera / Gallery / Dashboard tabs
- Live camera preview and capture flow
- Software HDR and Android hardware HDR bridge
- Exposure slider, aspect-ratio crop, horizon indicator, rule-of-thirds grid
- Post-capture `PhotoReviewScreen`
- Rule-based photo scoring and Vietnamese suggestions
- App-private gallery using JSON metadata + local image files
- Progress dashboard from saved photo evaluations
- Light/dark theme and shared UI components
- Plugin infrastructure: contract, registry, manager, context/output models
- AI DTOs and `AiEngine` interface

**Partial:**

- Plugin microkernel exists but is not wired into the camera runtime
- Retake flow exists, but ghost-outline retake is not implemented
- Aesthetic analysis exists, but it does not yet follow the original 0–100 four-factor `AestheticReport` contract
- Dashboard exists, but is not backed by a Hive learning log
- Style config JSON exists, but is not loaded at runtime

**Pending:**

- TFLite / AttributeNet integration
- YOLO or context detection on live preview frames
- EMD/style-distance scoring
- XAI mapping engine
- Production aesthetic plugins
- Subject mask extraction and normalized contour
- Ghost outline retake mode
- Hive persistence and repository layer
- Optional save/export to system gallery
- Broader unit/widget/integration tests

See [docs/current-state.md](docs/current-state.md) for implemented vs planned status and Excel plan comparison. Track checklist progress in [TODO.md](TODO.md).

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
