# Kiến trúc / X-Aesthetic Mobile Architecture

> **Implementation status:** This document describes both the **target architecture** and **current runtime**. For what is built today, see [current-state.md](current-state.md). Track progress in [TODO.md](../TODO.md).

---

## Repository layout

This repository **is** the Flutter mobile app. The project root contains `pubspec.yaml`, `lib/`, `android/`, `ios/`, and `docs/`.

```text
x-aesthetic-project/     # Flutter app root
├── lib/
├── assets/
├── docs/
├── android/
└── ios/
```

A separate Python training suite (`ai_training/`) may exist outside this repo in the broader university project; it is not part of this codebase.

---

## Architectural style

The mobile app uses a **microkernel-style plugin architecture**. The stable core owns camera context, AI output models, plugin contracts, and orchestration. Photography rules (Rule of Thirds, Symmetry, Horizon, Portrait Guide, Ghost Frame) are intended as independent plugins.

**Current gap:** Plugin infrastructure exists (`lib/core/plugin/`) but no production plugins are registered or called from the camera screen yet.

---

## App navigation

```text
CameraScreen (tab 0)
  → capture → PhotoReviewScreen (overlay)
  → save → GalleryScreen (tab 1)
  → DashboardScreen (tab 2)
```

Bottom navigation is hidden on the camera tab and during photo review.

---

## Current runtime flow

What actually runs in v0.2.0+2:

```text
Camera Preview
→ inline CustomPainter overlays (grid, horizon, static placeholders)
→ Capture
→ SoftwareHdrProcessor / HardwareHdrCameraBridge (Android)
→ AspectRatioProcessor crop
→ RuleBasedPhotoEvaluator
→ PhotoReviewScreen
→ AppGalleryStore (JSON + image files)
→ DashboardScreen
```

---

## Target runtime flow

North star — see [diagrams/system_architecture.mmd](diagrams/system_architecture.mmd):

```text
Camera Preview
→ Frame Preprocessor
→ Context Detector / Sensor Reader (YOLO / TFLite)
→ PluginManager
→ OverlayInstruction list
→ CustomPainter Overlay
→ Capture
→ Post-capture Analyzer
→ AttributeNet / Aesthetic Pipeline
→ Style Matcher + EMD
→ XAI Mapping Engine
→ Preview Feedback UI
→ Hive Learning Log
→ Dashboard
```

---

## Layer responsibilities

| Layer | Directory | Responsibility |
|---|---|---|
| App bootstrap | `lib/app` | Flutter init, shell, `XAestheticController` |
| Core plugin | `lib/core/plugin` | Plugin contract, registry, manager, I/O models |
| Core AI | `lib/core/ai` | Shared DTOs: detections, aesthetic attributes |
| Core camera | `lib/core/camera` | Camera frame and pose abstractions |
| Core common | `lib/core/common` | `Result`, `AppException` helpers |
| Domain | `lib/domain` | Entities, future repository contracts |
| Data | `lib/data` | `AppGalleryStore`; future Hive adapters |
| Services | `lib/services` | Camera processors, rule-based evaluator, `AiEngine` interface |
| Presentation | `lib/presentation` | Camera, gallery, photo review, dashboard UI |
| Assets | `assets/models`, `assets/style_configs` | TFLite models and style profiles |

---

## Dependency rules

- `presentation` may depend on `domain`, `core`, and `services`.
- `data` implements repository contracts from `domain` (when added).
- `services` may depend on `domain` and `core`.
- `core/plugin` must not depend on concrete UI widgets.
- Plugins return data instructions (`PluginOutput`), not Flutter widgets.
- Rendering is the responsibility of the presentation layer.

---

## Key services

| Service | Path | Role |
|---------|------|------|
| Software HDR | `lib/services/camera/software_hdr_processor.dart` | Tone mapping after capture |
| Aspect ratio | `lib/services/camera/aspect_ratio_processor.dart` | Center-crop to selected ratio |
| Hardware HDR | `lib/services/camera/hardware_hdr_camera_bridge.dart` | Android Camera2 native capture |
| Photo evaluator | `lib/services/analysis/rule_based_photo_evaluator.dart` | Heuristic post-capture scoring |
| AI engine | `lib/services/ai/ai_engine.dart` | Abstract interface — not implemented |

---

## Mermaid diagram

Target-state system diagram: [diagrams/system_architecture.mmd](diagrams/system_architecture.mmd)

---

## Related docs

- [Plugin contract](plugin_contract.md) — how to implement `AestheticPlugin`
- [Data and persistence](data-and-persistence.md) — gallery store and JSON schema
- [UI design](ui-design.md) — mockups and screen mapping
- [Getting started](getting-started.md) — run and platform setup
