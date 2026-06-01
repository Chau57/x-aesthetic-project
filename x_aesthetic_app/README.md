# X-Aesthetic Mobile App Skeleton

This folder contains the Flutter skeleton for the X-Aesthetic mobile application.

## Current Scope

This is the output of task `1.1 Infrastructure / Software Architecture Skeleton`:

- Standard Flutter app structure.
- Microkernel plugin contract.
- Plugin input/output models.
- Plugin registry and manager skeleton.
- Architecture documentation and Mermaid system diagram.
- Placeholder screens for Camera, Preview, and Dashboard.

Camera integration, TFLite inference, Hive persistence, and real UI implementation are intentionally left for later tasks.

## Folder Structure

```text
lib/
├── app/                  # Application bootstrap and shell
├── core/
│   ├── ai/               # Shared AI output models
│   ├── camera/           # Camera frame and device pose abstractions
│   ├── common/           # Common result and exception helpers
│   └── plugin/           # Microkernel plugin contract and manager
├── data/                 # Future Hive adapters, data sources, repositories
├── domain/               # Business entities and repository contracts
└── presentation/         # Camera, preview, and dashboard screens
```

## Plugin Contract

See `docs/plugin_contract.md`.

## Architecture Diagram

See `docs/diagrams/system_architecture.mmd`.

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```
