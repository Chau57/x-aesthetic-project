# Task 1.1 Output: Infrastructure / Software Architecture Skeleton

Owner: Trọng Doanh  
Target date: 22/05/2026

## Delivered Artifacts

| Requirement | Output |
|---|---|
| GitHub base project skeleton | `x_aesthetic_app/` Flutter skeleton added to the monorepo. |
| Standard empty folders | `lib/core`, `lib/domain`, `lib/data`, `lib/presentation`, `assets/models`, `assets/style_configs`. |
| System architecture drawing | `x_aesthetic_app/docs/diagrams/system_architecture.mmd`. |
| Plugin interface | `x_aesthetic_app/lib/core/plugin/base_plugin.dart`. |
| Plugin contract documentation | `x_aesthetic_app/docs/plugin_contract.md`. |
| Architecture explanation | `x_aesthetic_app/docs/architecture.md`. |
| Smoke test | `x_aesthetic_app/test/core/plugin/base_plugin_test.dart`. |

## Implemented Skeleton

The mobile app skeleton establishes a microkernel plugin architecture:

```text
Camera / Sensors / AI Context
→ PluginContext
→ PluginManager
→ AestheticPlugin implementations
→ PluginOutput
→ Overlay + Guidance UI
```

Plugins return declarative data (`OverlayInstruction`, `GuidanceMessage`, `metrics`) instead of Flutter widgets. This keeps rule logic independent from UI rendering.

## Handoff Notes for Following Tasks

- Task 1.2 can implement concrete plugins such as `RuleOfThirdsPlugin` and `HorizonStabilizerPlugin` using `AestheticPlugin`.
- UI tasks should render `OverlayInstruction` through `CustomPainter`.
- AI tasks should implement `AiEngine` and write results into `DetectionResult` and `AestheticAttributes`.
- Data tasks should implement Hive adapters for `AestheticResult` and related entities.
