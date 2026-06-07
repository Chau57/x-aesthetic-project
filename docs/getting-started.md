# Bắt đầu / Getting Started

Hướng dẫn setup môi trường và chạy X-Aesthetic trên thiết bị hoặc emulator.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | `^3.5.0` (see `pubspec.yaml`) |
| Dart | Bundled with Flutter |
| Android Studio or Xcode | For emulators and platform builds |
| Physical device (recommended) | Camera features need a real camera |

Verify your install:

```bash
flutter doctor
```

---

## Clone and install

```bash
git clone <repository-url>
cd x-aesthetic-project
flutter pub get
```

---

## Run the app

### Android (recommended for camera + HDR)

```bash
flutter run
```

`CAMERA` permission is declared in `android/app/src/main/AndroidManifest.xml`. Hardware HDR uses a custom `MethodChannel` in `MainActivity.kt` (Android only).

### iOS

```bash
flutter run
```

`NSCameraUsageDescription` is declared in `ios/Runner/Info.plist`. Run on a **physical iOS device** to verify the permission prompt and camera preview (tracked in [TODO.md](../TODO.md) Phase 13).

### Desktop / emulator without camera

The app shows a graceful fallback UI (`_MockPortraitPainter`) when no camera is available. You can navigate Gallery and Dashboard but cannot capture photos.

---

## Quality checks

Run before opening a PR:

```bash
flutter analyze
flutter test
```

---

## First-run smoke test

Use a physical Android device when possible.

1. Launch app — home tab is **Chụp** (Camera).
2. Grant camera permission when prompted.
3. Open settings sheet — adjust exposure, HDR mode, aspect ratio, photo context.
4. Observe horizon tilt indicator while tilting the device.
5. Tap shutter — review overlay opens with captured image.
6. Tap analyze / view score — rule-based evaluation runs.
7. Save to library — photo appears in **Thư viện** tab.
8. Open **Tiến độ** tab — dashboard reflects saved photo stats.

---

## Troubleshooting

| Issue | Cause | Workaround |
|-------|-------|------------|
| Black camera preview | Emulator has no camera | Use physical device |
| HDR+ falls back to Strong | Device lacks Camera2 HDR scene mode | Expected on unsupported hardware |
| Black image after HDR+ | Native capture failed | App auto-falls back to software HDR |
| iOS camera crash / denied | Missing `NSCameraUsageDescription` | Use Android until Phase 2 task is done |
| `flutter: command not found` | Flutter not on PATH | Install Flutter SDK and add to shell PATH |
| Gallery empty after reinstall | App documents cleared | Expected — library is app-private |

---

## Project layout (quick reference)

```text
lib/app/           → entry, shell, controller
lib/presentation/  → screens and shared UI
lib/services/      → camera processors, evaluator, AI interface
lib/data/local/    → AppGalleryStore
docs/              → architecture and onboarding docs
TODO.md            → phased progress checklist
```

Next: [current-state.md](current-state.md) · [contributing.md](contributing.md)
