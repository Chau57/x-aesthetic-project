# X-Aesthetic Mobile Architecture

This skeleton follows a monorepo layout. The Python training suite remains in `ai_training/`, while the mobile system lives in `x_aesthetic_app/`.

## Architectural Style

The mobile app uses a microkernel-style plugin architecture. The stable core owns camera context, AI output models, plugin contracts, and orchestration. Photography rules such as Rule of Thirds, Symmetry, Horizon, Portrait Guide, and Ghost Frame are implemented as independent plugins.

## Main Runtime Flow

```text
Camera Preview
→ Frame Preprocessor
→ Context Detector / Sensor Reader
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

## Layer Responsibilities

| Layer | Directory | Responsibility |
|---|---|---|
| App bootstrap | `lib/app` | Initializes Flutter and application shell. |
| Core plugin | `lib/core/plugin` | Defines plugin contract, registry, manager, plugin input/output models. |
| Core AI | `lib/core/ai` | Shared AI result objects such as detections and aesthetic attributes. |
| Core camera | `lib/core/camera` | Camera frame and camera pose abstractions. |
| Domain | `lib/domain` | Business entities such as aesthetic rules, reference styles, and results. |
| Data | `lib/data` | Future repositories, Hive adapters, local persistence, and AI data sources. |
| Presentation | `lib/presentation` | Camera screen, preview diagnosis screen, and learning dashboard UI. |
| Assets | `assets/models`, `assets/style_configs` | TFLite models and configurable reference style profiles. |

## Dependency Rule

- `presentation` may depend on `domain` and `core`.
- `data` implements repository contracts from `domain`.
- `core/plugin` should not depend on concrete UI widgets.
- Plugins return data instructions, not Flutter widgets.
- Rendering is the responsibility of the presentation layer.

## Mermaid Diagram

See `docs/diagrams/system_architecture.mmd`.
