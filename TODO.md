# X-Aesthetic — Roadmap & Tiến độ

**Version:** `0.2.0+2`  
**Source of truth** cho tiến độ dự án — checklist theo phase.

## Legend

| Ký hiệu | Ý nghĩa |
|---------|---------|
| `[x]` | Done — đã implement và hoạt động trong codebase |
| `[~]` | Partial — đã có một phần, nhưng chưa đúng đầy đủ scope/contract ban đầu |
| `[ ]` | Pending — chưa làm hoặc chỉ có skeleton/interface |

**Hiện trạng & so sánh plan Excel:** [docs/current-state.md](docs/current-state.md)

---

## Phase 1 — Nền tảng & App Shell

*Application bootstrap, global state, navigation shell.*

- [x] `main.dart` → `bootstrap()` → `XAestheticApp`
- [x] `lib/app/bootstrap.dart` — `WidgetsFlutterBinding`, `runApp`
- [x] `lib/app/app.dart` — 3-tab shell: Chụp / Thư viện / Tiến độ
- [x] `PhotoReviewScreen` as full-screen overlay after capture
- [x] `lib/app/x_aesthetic_controller.dart` — settings, library, current capture
- [x] Light / dark theme via `CameraUserSettings.themeMode`
- [~] Plugin infrastructure exists, but `PluginManager` / `PluginRegistry` are not wired at app startup
- [ ] Inject concrete `AiEngine` implementation into controller / services
- [ ] Persist `CameraUserSettings` across app restarts

---

## Phase 2 — Camera & Chụp ảnh

*Live preview, capture pipeline, HDR, horizon, exposure.*

- [x] Live camera preview using `camera` plugin
- [x] Camera lifecycle handling
- [x] Capture flow: `takePicture` → HDR → aspect crop → metadata → review
- [x] Exposure offset slider
- [x] Horizon tilt via `sensors_plus` accelerometer + calibration
- [x] Aspect ratio preview mask + post-capture crop via `AspectRatioProcessor`
- [x] Rule-of-thirds grid overlay via `CustomPainter`
- [x] Front / back camera switch
- [x] Resolution preset selector
- [x] Software HDR — Light / Strong via `SoftwareHdrProcessor`
- [x] Android hardware HDR bridge via `HardwareHdrCameraBridge` + `MainActivity.kt`
- [x] Photo context selector stored in capture metadata
- [x] Graceful fallback when no camera is available
- [~] Retake flow exists, but only as normal retake; not ghost-outline retake
- [~] Subject outline exists only as static placeholder; not AI/segmentation-based
- [ ] Live frame analysis using `startImageStream`
- [ ] Use `AiEngine.detectContext` on preview frames
- [ ] Plugin-driven overlays from `PluginOutput`
- [ ] Replace static overlay painters with plugin-rendered `OverlayInstruction`
- [ ] iOS hardware HDR support
- [x] Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`

---

## Phase 3 — Post-capture Analysis & Aesthetic Report

*Report contract, scoring, suggestions, save / retake flow.*

- [x] `PhotoReviewScreen` — analysis panel, save, retake, close
- [x] `RuleBasedPhotoEvaluator` — heuristic lighting, contrast, color, balance, HDR metrics
- [x] Context-aware scoring and suggestions via `PhotoContext`
- [x] Re-evaluate on demand from review screen
- [x] Evaluation persisted on save via `AppGalleryStore.updatePhoto`
- [~] Overall score exists, but current scale is 0–10; original plan expects 0–100
- [~] Metrics exist, but not always the fixed 4 factors: Lighting / Composition / Subject / Background
- [~] Suggestions exist, but not yet exposed as stable `mainSuggestion` + `factorSuggestions`
- [ ] Define stable `AestheticReport` data contract:
  - `overallScore`
  - `lightingScore`
  - `compositionScore`
  - `subjectScore`
  - `backgroundScore`
  - `weakestFactor`
  - `mainSuggestion`
  - `factorSuggestions`
  - optional `subjectContour`
- [ ] Normalize score scale to 0–100 or explicitly document 0–10 as a changed requirement
- [ ] Implement fixed 4-factor scoring layer on top of current rule-based evaluator
- [ ] Implement `weakestFactor` detection
- [ ] Implement factor-specific suggestion thresholds
- [ ] Replace rule-based evaluator with `AiEngine.predictAttributes` when ML pipeline is ready
- [ ] TFLite AttributeNet / aesthetic pipeline integration
- [ ] Style delta advisor comparing captured image to `ReferenceStyle`
- [ ] Retire legacy `PreviewScreen`

---

## Phase 4 — Suggestion Engine & XAI Mapping

*Actionable advice from scoring errors / attribute deltas.*

- [x] Basic Vietnamese suggestions from `RuleBasedPhotoEvaluator`
- [~] Suggestions are actionable in many cases, but are not yet formalized as a separate engine
- [ ] Create dedicated suggestion/XAI service
- [ ] Generate one `mainSuggestion` from `weakestFactor`
- [ ] Generate factor suggestions for low-scoring factors
- [ ] Add lighting-specific suggestions:
  - too dark
  - overexposed
  - backlit
  - low dynamic range
- [ ] Add composition-specific suggestions:
  - subject too centered
  - subject too close to edge
  - subject too small/large
  - horizon tilted
- [ ] Add subject-specific suggestions:
  - subject unclear
  - subject too small
  - low contrast with background
  - blurry subject
- [ ] Add background-specific suggestions:
  - cluttered background
  - distracting bright background
  - poor subject-background separation
- [ ] Map AttributeNet / EMD deltas to natural-language suggestions when AI pipeline lands

---

## Phase 5 — Ghost Outline Retake

*Subject mask, contour normalization, and retake guide overlay.*

- [ ] Extract subject mask / contour from captured image
- [ ] Evaluate integration options:
  - YOLOv8-seg
  - MediaPipe
  - SAM / mobile-compatible segmentation
  - simpler rule-based fallback
- [ ] Convert contour to normalized coordinates `[0,1]`
- [ ] Store contour in `AestheticReport` or related review state
- [ ] Add `retakeGuide` camera mode
- [ ] Render ghost outline on live camera preview
- [ ] Add retake instruction text
- [ ] Hide ghost retake when segmentation fails
- [ ] Ensure retake mode uses static saved contour, not realtime segmentation
- [ ] Validate orientation/aspect ratio alignment between captured image and preview

---

## Phase 6 — Thư viện & Lưu trữ

*Local photo library and persistence layer.*

- [x] `AppGalleryStore` — JSON metadata + image files in app documents dir
- [x] `saveCapturedImage`, `loadPhotos`, `updatePhoto`, `deletePhoto`
- [x] `GalleryScreen` — grid, refresh, delete confirm, empty state
- [x] App-private library
- [~] Save image exists, but not to the system photo gallery
- [ ] Add optional save/export to system gallery
- [ ] Hive learning log per target architecture
- [ ] Repository pattern in `lib/domain/repositories/` and `lib/data/repositories/`
- [ ] Migrate gallery metadata from JSON to Hive adapters
- [ ] Persist `CameraUserSettings` to local storage
- [ ] Add user data deletion path if long-term history is stored
- [ ] Keep JSON export/debug mode optional after Hive migration

---

## Phase 7 — Dashboard & Learning Progress

*Learning progress and analytics UI.*

- [x] `DashboardScreen` — weekly average score card
- [x] Factor improvement grid from saved evaluations
- [x] Photo context distribution chart
- [x] "Need more practice" recommendations
- [x] Recent photos horizontal strip
- [~] Dashboard exists, but is based on saved photo JSON rather than Hive learning events
- [ ] Hive-backed learning history
- [ ] Time-series trend chart
- [ ] Before/after comparison after retake
- [ ] Export / share progress report
- [ ] Streak and goal tracking
- [ ] Track most common mistakes over time

---

## Phase 8 — UI & Design System

*Shared components, themes, mockup alignment.*

- [x] `lib/presentation/shared/x_theme.dart` — design tokens, light / dark themes
- [x] `lib/presentation/shared/x_widgets.dart` — cards, nav, thumbnails, empty states
- [x] Bottom navigation hidden on camera tab and review overlay
- [x] Vietnamese UI copy across main screens
- [x] UI mockup index in `docs/ui-design.md`
- [~] Camera UI has static overlays; AI/plugin overlays are pending
- [ ] Retire or repurpose `lib/presentation/preview/preview_screen.dart`
- [ ] Ghost frame overlay renderer
- [ ] Heatmap overlay renderer
- [ ] Render generic `OverlayInstruction` list from plugins
- [ ] Align final UI with mockups in `docs/ui_mockups/`

---

## Phase 9 — Plugin Microkernel

*Composable aesthetic guidance via `AestheticPlugin` contract.*

- [x] `AestheticPlugin` interface
- [x] `PluginContext`
- [x] `PluginOutput`
- [x] `OverlayInstruction`
- [x] `GuidanceMessage`
- [x] `PluginRegistry`
- [x] `PluginManager`
- [x] `docs/plugin_contract.md`
- [x] Unit test with mock plugin
- [~] Plugin architecture exists, but production plugins do not exist yet
- [ ] Create `lib/domain/plugins/`
- [ ] Implement `rule_of_thirds` plugin
- [ ] Implement `horizon_stabilizer` plugin
- [ ] Implement `symmetry_guide` plugin
- [ ] Implement `portrait_guide` plugin
- [ ] Implement `ghost_frame` plugin
- [ ] Implement `style_delta_advisor` plugin
- [ ] Register plugins at startup
- [ ] Call `PluginManager.evaluate` during camera preview loop
- [ ] Render `OverlayInstruction` list in camera `CustomPainter`
- [ ] Add tests for plugin priority, activation, and failure isolation

---

## Phase 10 — AI & ML Pipeline

*TFLite inference, context detection, attribute prediction.*

- [x] `DetectionResult` DTO
- [x] `AestheticAttributes` DTO
- [x] `AiEngine` abstract interface
- [ ] Add `tflite_flutter` or chosen runtime to `pubspec.yaml`
- [ ] Ship TFLite models in `assets/models/`
- [ ] Implement concrete `AiEngine`
- [ ] Context detection using YOLO/object labels on preview frames
- [ ] Attribute prediction on captured images
- [ ] Implement 29-attribute aesthetic vector pipeline from original plan
- [ ] Implement style matcher
- [ ] Implement EMD distance between captured attributes and reference style
- [ ] Implement XAI mapping engine from attribute deltas to suggestions
- [ ] Add loading/error states for model initialization and inference
- [ ] Ensure heavy inference does not freeze UI

---

## Phase 11 — Style Configs & Domain

*Reference styles and domain model completeness.*

- [x] `ReferenceStyle` entity
- [x] `PhotoContext` entity with auto / portrait / landscape / etc.
- [x] `CapturedPhoto`, `CaptureMetadata`, `PhotoEvaluation` with JSON serialization
- [x] `AestheticRule` entity exists
- [x] `AestheticResult` entity exists
- [x] Sample `assets/style_configs/default_styles.json`
- [~] Domain entities exist, but some are not wired into runtime flow
- [ ] Load style configs from assets at runtime using `rootBundle`
- [ ] Wire `ReferenceStyle` into `PluginContext`
- [ ] Wire `ReferenceStyle` into evaluator / style matcher
- [ ] Wire `AestheticRule` into plugin/scoring pipeline
- [ ] Wire `AestheticResult` or replace with stable `AestheticReport`
- [ ] Document final domain model after contract is finalized

---

## Phase 12 — Non-functional Requirements

*Performance, reliability, privacy, maintainability.*

### Performance

- [~] Camera preview works, but FPS is not measured
- [ ] Target at least 30 FPS when no heavy analysis runs
- [ ] Ensure capture/post-capture flow does not freeze UI
- [ ] Run heavy inference in isolate/thread or async service
- [ ] Target 1–3 seconds for local post-capture analysis in MVP
- [ ] Retake guide must not run segmentation realtime

### Reliability

- [x] Camera fallback exists for unsupported desktop/emulator environments
- [~] Orientation/aspect-ratio handling exists, but contour alignment is not validated
- [ ] Gracefully handle segmentation failure
- [ ] Gracefully handle TFLite/model loading failure
- [ ] Handle dark, blurry, overexposed, or no-subject images without crash
- [ ] Validate orientation and aspect ratio for saved image, review screen, and ghost contour

### Privacy

- [x] Current library is app-private
- [ ] Add clear permission copy for camera/gallery usage
- [ ] Avoid hidden image upload unless explicitly agreed
- [ ] Add user deletion path for saved history
- [ ] Document local-first processing policy

### Maintainability

- [x] Layered folder structure exists
- [x] Plugin contract keeps rules separate from UI widgets
- [~] Scoring engine is replaceable in design, but current UI still uses rule-based evaluator directly
- [ ] Add repository interfaces
- [ ] Centralize scoring weights and thresholds
- [ ] Avoid hard-coded thresholds scattered across evaluator
- [ ] Add architectural decision record for rule-based MVP vs ML target

---

## Phase 13 — Kiểm thử & Chất lượng

*Automated tests and quality gates.*

- [x] `test/widget_test.dart` — app smoke test
- [x] `test/core/plugin/base_plugin_test.dart` — plugin manager test
- [x] `analysis_options.yaml` — `flutter_lints` enabled
- [ ] Unit tests for `RuleBasedPhotoEvaluator`
- [ ] Unit tests for `AppGalleryStore`
- [ ] Unit tests for `SoftwareHdrProcessor`
- [ ] Unit tests for `AspectRatioProcessor`
- [ ] Unit tests for score normalization and `weakestFactor`
- [ ] Unit tests for suggestion engine
- [ ] Widget tests for `GalleryScreen`
- [ ] Widget tests for `DashboardScreen`
- [ ] Widget tests for `PhotoReviewScreen`
- [ ] Integration tests for capture → review → save → dashboard flow
- [ ] Manual QA checklist for Android physical device
- [ ] Manual QA checklist for iOS physical device

---

## Phase 14 — Tài liệu & Onboarding

*Team docs, architecture references, contribution guide.*

- [x] `README.md`
- [x] `docs/architecture.md`
- [x] `docs/plugin_contract.md`
- [x] `docs/diagrams/system_architecture.mmd`
- [x] `docs/current-state.md`
- [x] `docs/getting-started.md`
- [x] `docs/contributing.md`
- [x] `docs/ui-design.md`
- [x] `docs/data-and-persistence.md`
- [ ] Add `CHANGELOG.md`
- [ ] Add `docs/non-functional-requirements.md`
- [ ] Add `docs/aesthetic-report-contract.md`
- [ ] Add `docs/manual-qa-checklist.md`
