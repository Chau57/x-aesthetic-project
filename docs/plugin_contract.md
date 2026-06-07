# Plugin Contract

All aesthetic guidance rules must implement `AestheticPlugin` from `lib/core/plugin/base_plugin.dart`.

## Design Goals

- Add or remove photography rules without changing the camera core.
- Allow AI context labels to activate different guidance plugins.
- Keep plugin logic testable and independent from Flutter widget rendering.
- Support both pre-capture guidance and post-capture diagnosis.

## Required Interface

```dart
abstract interface class AestheticPlugin {
  String get id;
  String get name;
  String get description;
  PluginStatus get status;
  Set<PluginPhase> get supportedPhases;
  Set<String> get supportedContextLabels;
  int get priority;
  bool shouldActivate(PluginContext context);
  Future<PluginOutput> evaluate(PluginContext context);
}
```

## Input: PluginContext

`PluginContext` contains the current execution phase, optional camera frame, camera pose, AI detections, aesthetic attributes, target reference style, and metadata.

Typical pre-capture context:

```text
phase = preCapture
detections = [person, chair, dog, ...]
cameraPose = roll/pitch/yaw from sensors
frame = preview frame metadata
```

Typical post-capture context:

```text
phase = postCapture
attributes = lighting, composition, color harmony, symmetry, ...
targetStyle = Noir / Vibrant / Minimal / custom style
```

## Output: PluginOutput

A plugin returns:

- `overlays`: declarative drawing instructions such as rule-of-thirds grid, horizon line, heatmap, or ghost frame.
- `messages`: user-facing advice written by the XAI mapping logic.
- `metrics`: numeric values such as horizon delta, composition distance, or style similarity.

Plugins should not return Flutter widgets. They should return data only.

## Activation Rules

The `PluginManager` executes only plugins that:

1. Have `PluginStatus.active`.
2. Support the current `PluginPhase`.
3. Return `true` from `shouldActivate(context)`.

Candidates are sorted by descending `priority`. Higher priority plugins run first.

## Naming Convention

Recommended plugin ids:

```text
rule_of_thirds
horizon_stabilizer
symmetry_guide
portrait_guide
ghost_frame
style_delta_advisor
```

Recommended file layout:

```text
lib/core/plugin/base_plugin.dart
lib/domain/plugins/rule_of_thirds_plugin.dart
lib/domain/plugins/horizon_stabilizer_plugin.dart
```

> **Note:** `lib/domain/plugins/` is the **planned location** for production plugins. The directory does not exist yet — see [TODO.md](../TODO.md) Phase 7.
