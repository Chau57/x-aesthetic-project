# X-Aesthetic — Roadmap & Tiến độ

**Version:** `0.2.0+2`  
**Source of truth** cho tiến độ dự án. Cập nhật file này khi hoàn thành hoặc thay đổi phạm vi task.

## Legend

| Ký hiệu | Ý nghĩa |
|---------|---------|
| `[x]` | Done — đã implement và hoạt động trong codebase |
| `[ ]` | Pending — chưa làm hoặc chỉ có skeleton |

**Chi tiết hiện trạng:** [docs/current-state.md](docs/current-state.md)

---

## Phase 1 — Nền tảng & App Shell

*Application bootstrap, global state, navigation shell.*

- [x] `main.dart` → `bootstrap()` → `XAestheticApp`
- [x] `lib/app/bootstrap.dart` — `WidgetsFlutterBinding`, `runApp`
- [x] `lib/app/app.dart` — 3-tab shell (Chụp / Thư viện / Tiến độ)
- [x] `PhotoReviewScreen` as full-screen overlay after capture
- [x] `lib/app/x_aesthetic_controller.dart` — settings, library, current capture
- [x] Light / dark theme via `CameraUserSettings.themeMode`
- [ ] Wire `PluginManager` and `PluginRegistry` at app startup
- [ ] Inject `AiEngine` implementation into controller / services
- [ ] Persist camera settings across app restarts

---

## Phase 2 — Camera & Chụp ảnh

*Live preview, capture pipeline, HDR, horizon, exposure.*

- [x] Live camera preview (`camera` plugin, lifecycle handling)
- [x] Capture flow: `takePicture` → HDR → aspect crop → metadata → review
- [x] Exposure offset slider (`getMin/MaxExposureOffset`)
- [x] Horizon tilt via `sensors_plus` accelerometer + calibration
- [x] Aspect ratio preview mask + post-capture crop (`AspectRatioProcessor`)
- [x] Rule-of-thirds grid overlay (`CustomPainter`)
- [x] Front / back camera switch
- [x] Resolution preset selector
- [x] Software HDR — Light / Strong (`SoftwareHdrProcessor`)
- [x] Android hardware HDR bridge (`HardwareHdrCameraBridge` + `MainActivity.kt`)
- [x] Photo context selector (stored in settings / metadata)
- [x] Graceful fallback when no camera (desktop / emulator mock)
- [ ] Live frame analysis (`startImageStream` + `AiEngine.detectContext`)
- [ ] Plugin-driven overlays from `PluginOutput` (replace static painters)
- [ ] AI-based subject outline (replace static placeholder rect)
- [ ] iOS hardware HDR support
- [ ] Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`

---

## Phase 3 — Phân tích sau chụp

*Post-capture review, scoring, save / retake flow.*

- [x] `PhotoReviewScreen` — analysis panel, save, retake, close
- [x] `RuleBasedPhotoEvaluator` — lighting, contrast, color, balance, HDR metrics
- [x] Context-aware scoring and suggestions (`PhotoContext`)
- [x] Evaluation persisted on save via `AppGalleryStore.updatePhoto`
- [x] Re-evaluate on demand from review screen
- [ ] Replace rule-based evaluator with `AiEngine.predictAttributes`
- [ ] TFLite AttributeNet / aesthetic pipeline integration
- [ ] Style delta advisor (compare to `ReferenceStyle`)
- [ ] Retire legacy `PreviewScreen` (hardcoded stub, not wired in `app.dart`)

---

## Phase 4 — Thư viện & Lưu trữ

*Local photo library and persistence layer.*

- [x] `AppGalleryStore` — JSON metadata + image files in app documents dir
- [x] `saveCapturedImage`, `loadPhotos`, `updatePhoto`, `deletePhoto`
- [x] `GalleryScreen` — grid, refresh, delete confirm, empty state
- [x] App-private library (not system photo gallery)
- [ ] Hive learning log (per target architecture)
- [ ] Repository pattern (`lib/domain/repositories/`, `lib/data/repositories/`)
- [ ] Migrate gallery metadata from JSON to Hive adapters
- [ ] Persist `CameraUserSettings` to local storage

---

## Phase 5 — Dashboard & Tiến độ

*Learning progress and analytics UI.*

- [x] `DashboardScreen` — weekly average score card
- [x] Factor improvement grid from saved evaluations
- [x] Photo context distribution chart
- [x] "Need more practice" recommendations
- [x] Recent photos horizontal strip
- [ ] Hive-backed learning history (time-series trends)
- [ ] Export / share progress report
- [ ] Streak and goal tracking

---

## Phase 6 — UI & Design System

*Shared components, themes, mockup alignment.*

- [x] `lib/presentation/shared/x_theme.dart` — design tokens, light / dark themes
- [x] `lib/presentation/shared/x_widgets.dart` — cards, nav, thumbnails, empty states
- [x] Bottom navigation (hidden on camera tab and review overlay)
- [x] Vietnamese UI copy across main screens
- [x] UI mockup index in `docs/ui-design.md`
- [ ] Retire or repurpose `lib/presentation/preview/preview_screen.dart`
- [ ] Ghost frame / heatmap overlay renderers (when plugins land)

---

## Phase 7 — Plugin Microkernel

*Composable aesthetic guidance via `AestheticPlugin` contract.*

- [x] `AestheticPlugin` interface (`lib/core/plugin/base_plugin.dart`)
- [x] `PluginContext`, `PluginOutput`, `OverlayInstruction`, `GuidanceMessage`
- [x] `PluginRegistry` — register / unregister / findById
- [x] `PluginManager` — phase filter, `shouldActivate`, priority sort
- [x] `docs/plugin_contract.md`
- [x] Unit test with mock plugin (`test/core/plugin/base_plugin_test.dart`)
- [ ] Create `lib/domain/plugins/` directory and production plugins
- [ ] Implement `rule_of_thirds` plugin
- [ ] Implement `horizon_stabilizer` plugin
- [ ] Implement `symmetry_guide` plugin
- [ ] Implement `portrait_guide` plugin
- [ ] Implement `ghost_frame` plugin
- [ ] Register plugins at startup in `bootstrap.dart` or controller
- [ ] Call `PluginManager.evaluate` during camera preview loop
- [ ] Render `OverlayInstruction` list in camera `CustomPainter`

---

## Phase 8 — AI & ML Pipeline

*TFLite inference, context detection, attribute prediction.*

- [x] `DetectionResult` DTO (`lib/core/ai/detection_result.dart`)
- [x] `AestheticAttributes` DTO (`lib/core/ai/aesthetic_attributes.dart`)
- [x] `AiEngine` abstract interface (`lib/services/ai/ai_engine.dart`)
- [ ] Add `tflite_flutter` (or chosen runtime) to `pubspec.yaml`
- [ ] Ship TFLite models in `assets/models/`
- [ ] Implement `AiEngine` concrete class
- [ ] Context detection (YOLO / object labels) on preview frames
- [ ] Attribute prediction on captured images
- [ ] Style matcher + EMD distance
- [ ] XAI mapping engine (natural-language suggestions from attributes)

---

## Phase 9 — Style Configs & Domain

*Reference styles and domain model completeness.*

- [x] `ReferenceStyle` entity (`lib/domain/entities/reference_style.dart`)
- [x] `PhotoContext` entity with auto / portrait / landscape / etc.
- [x] `CapturedPhoto`, `CaptureMetadata`, `PhotoEvaluation` with JSON serialization
- [x] Sample `assets/style_configs/default_styles.json` (noir, vibrant, minimal)
- [ ] Load style configs from assets at runtime (`rootBundle`)
- [ ] Wire `ReferenceStyle` into `PluginContext` and evaluator
- [ ] Implement or wire `AestheticRule` entity
- [ ] Implement or wire `AestheticResult` entity

---

## Phase 10 — Kiểm thử & Chất lượng

*Automated tests and quality gates.*

- [x] `test/widget_test.dart` — app smoke test
- [x] `test/core/plugin/base_plugin_test.dart` — plugin manager test
- [x] `analysis_options.yaml` — `flutter_lints` enabled
- [ ] Unit tests for `RuleBasedPhotoEvaluator`
- [ ] Unit tests for `AppGalleryStore`
- [ ] Unit tests for `SoftwareHdrProcessor` and `AspectRatioProcessor`
- [ ] Widget tests for `GalleryScreen` and `DashboardScreen`
- [ ] Integration tests (`integration_test/`)

---

## Phase 11 — Tài liệu & Onboarding

*Team docs, architecture references, contribution guide.*

- [x] `docs/architecture.md` (updated for current vs target state)
- [x] `docs/plugin_contract.md`
- [x] `docs/diagrams/system_architecture.mmd` (target-state diagram)
- [x] `docs/current-state.md`
- [x] `docs/getting-started.md`
- [x] `docs/contributing.md`
- [x] `docs/ui-design.md`
- [x] `docs/data-and-persistence.md`
- [x] `README.md` updated for v0.2.0+2
- [ ] `CHANGELOG.md` version history
