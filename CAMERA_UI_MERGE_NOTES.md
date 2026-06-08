# Camera UI merge notes

## Mục tiêu
Ghép giao diện camera kiểu Xiaomi từ `src_ui.zip` vào màn hình camera của core app, nhưng không copy nguyên `CameraController` và `CameraState` riêng của UI demo để tránh phá pipeline hiện tại.

## File chính đã sửa
- `lib/presentation/camera/camera_screen.dart`
- `test/widget_test.dart`

## Hướng ghép
- Giữ lại core logic hiện có:
  - khởi tạo/hủy camera theo lifecycle;
  - `takePicture()`;
  - HDR phần cứng qua `HardwareHdrCameraBridge`;
  - HDR phần mềm qua `SoftwareHdrProcessor`;
  - crop ảnh bằng `AspectRatioProcessor`;
  - lưu metadata vào `XAestheticController`;
  - mở review sau khi chụp;
  - mở ảnh mới nhất trong gallery.
- Thay UI màn camera bằng layout kiểu Xiaomi:
  - thanh top control có close, flash, setting dropdown;
  - setting panel gồm tỉ lệ khung hình, hẹn giờ, HDR, dark/light, lưới, horizon, subject outline;
  - viewfinder theo tỉ lệ 1:1 / 3:4 / 9:16 / Full;
  - EV button trong viewfinder;
  - EV dial dạng cuộn ngang;
  - zoom selector;
  - mode scroller `Chuyên nghiệp` / `Nghiệp dư`;
  - shutter controls + thumbnail + switch camera.

## Điểm cần kiểm thử thật trên máy Android/iOS
1. Chạy `flutter pub get`.
2. Chạy `flutter analyze`.
3. Chạy trên thiết bị thật vì camera plugin thường không chạy đầy đủ trên desktop/test.
4. Kiểm thử các case:
   - chụp thường;
   - đổi camera trước/sau;
   - đổi tỉ lệ 1:1, 3:4, 9:16, Full;
   - kéo EV dial ngang;
   - tap focus và kéo EV cạnh focus box;
   - zoom 1x/2x/5x nếu thiết bị hỗ trợ;
   - HDR Mạnh/HDR+ fallback;
   - mở latest photo và review flow.

## Lưu ý kỹ thuật
UI demo ban đầu có `CameraViewport` tự tạo `CameraController` riêng. Bản merge không dùng controller riêng đó; tất cả camera operation đi qua state của `CameraScreen` trong core để tránh double-open camera và tránh mất luồng HDR/gallery.

## 2026-06-08 follow-up fixes

- Fixed the Xiaomi top-right settings toggle by removing the parent full-screen tap handler that could conflict with the nested settings button tap target.
- Kept settings closing on viewfinder tap through the existing viewfinder tap handler.
- Moved the EV dial in normal aspect-ratio mode out of the bottom deck and into a `Stack` overlay above the shutter/mode deck, so opening EV no longer shrinks or pushes the camera preview upward.
- Adjusted the EV reset button vertical offset and hit behavior so it aligns better with the scrollable EV ruler.

## 2026-06-08 render-fix

- Replaced the settings panel `AnimatedCrossFade` with `ClipRect + AnimatedSize + conditional child`, so the hidden settings panel is no longer laid out with zero width. This fixes the Flutter test/runtime error: `RenderFlex children have non-zero flex but incoming width constraints are unbounded`.
- Applied the same safe animation pattern to the full-screen EV dial in the overlay bottom deck.
- Made `_XiaomiSettingsPanel` shrink-wrap vertically and made `_XiaomiIconPill`'s internal row use `MainAxisSize.min` to avoid flex conflicts when used in shrink-wrapped rows.
- Re-aligned the EV reset button toward the ruler/tick area by giving it a fixed 52x84 slot and bottom alignment, while keeping the EV dial as an overlay in normal camera mode.

## Fix v3 - aspect ratio and horizon

- Guarded `_XiaomiCameraViewport` against transient zero-size Android/CameraX layout passes. This fixes the `Invalid argument(s): 10.0` crash when switching to `Full` while the camera surface is being rebuilt.
- Reworked the viewfinder sizing logic from “full width then clamp height” to “fit the requested ratio inside the available area”. This makes `1:1`, `3:4`, and `9:16` visually distinct instead of looking nearly identical when height is constrained.
- Kept `Full` as an uncropped full-area preview layout.
- Reworked horizon data to keep the raw accelerometer roll and compensate for Flutter landscape orientation only at render time. This prevents the horizon line from becoming perpendicular to the real ground when the phone is held sideways.

## Patch v4 - viewport overflow, horizon, EV reset alignment
- Fixed a narrow-preview overflow in `_XiaomiViewportControls` by using a compact zoom chip and hiding the filter shortcut when the viewport is too narrow, such as 1:1 preview on tall Android screens.
- Changed horizon rendering to use only the small error around the nearest 90-degree device axis, so the level line no longer stands upright when the phone is held sideways.
- Moved the EV reset button downward inside the EV dial so its visual center aligns better with the scroll ruler/ticks.
