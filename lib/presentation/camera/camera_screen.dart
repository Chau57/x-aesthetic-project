import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../app/x_aesthetic_controller.dart';
import '../../domain/entities/camera_settings.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/photo_context.dart';
import '../../services/camera/aspect_ratio_processor.dart';
import '../../services/camera/hardware_hdr_camera_bridge.dart';
import '../../services/camera/software_hdr_processor.dart';
import '../shared/x_theme.dart';
import '../shared/x_widgets.dart';

class CameraScreen extends StatefulWidget {
  final ValueChanged<String> onImageCaptured;
  final ValueChanged<String> onOpenLatestPhoto;
  final VoidCallback onClose;

  const CameraScreen({
    required this.onImageCaptured,
    required this.onOpenLatestPhoto,
    required this.onClose,
    super.key,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  bool _initializing = true;
  bool _capturing = false;
  String? _errorMessage;
  ResolutionPreset? _lastResolutionPreset;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _tiltDegrees = 0;
  double _horizonCalibration = 0;
  double _minExposureOffset = 0;
  double _maxExposureOffset = 0;
  bool _hardwareHdrAvailable = false;
  bool _checkingHardwareHdr = false;
  String _captureStatus = '';
  final HardwareHdrCameraBridge _hardwareHdrBridge =
      const HardwareHdrCameraBridge();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startHorizonSensor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeCamera();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSubscription?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      if (state == AppLifecycleState.resumed) {
        _initializeCamera();
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_detachAndDisposeCamera());
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _detachAndDisposeCamera({bool showInitializing = false}) async {
    final controller = _cameraController;
    if (controller == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _cameraController = null;
        _initializing = showInitializing;
      });

      // Let Flutter rebuild one frame without CameraPreview before disposing.
      // Otherwise CameraPreview may try to render a disposed CameraController,
      // especially when HDR+ temporarily releases the Flutter camera for native Camera2.
      await WidgetsBinding.instance.endOfFrame;
    } else {
      _cameraController = null;
    }

    await controller.dispose();
  }

  Future<void> _initializeCamera() async {
    final settings = XAestheticScope.of(context).settings;
    setState(() {
      _initializing = true;
      _errorMessage = null;
      _lastResolutionPreset = settings.resolutionPreset;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException(
            'no_camera', 'Không tìm thấy camera khả dụng trên thiết bị này.');
      }

      final camera = _cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      await _refreshHardwareHdrSupport(camera.lensDirection);
      await _openCamera(camera, settings);
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _errorMessage = error.description ?? 'Không thể khởi tạo camera.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _errorMessage =
            'Camera chưa khả dụng trên môi trường hiện tại. Trên Linux desktop có thể chỉ xem được UI, hãy chạy trên Android/iOS để chụp thật.';
      });
    }
  }

  Future<void> _openCamera(
      CameraDescription camera, CameraUserSettings settings) async {
    await _detachAndDisposeCamera(showInitializing: true);

    final controller = CameraController(
      camera,
      settings.resolutionPreset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      await _applyCameraCapabilities(controller, settings.exposureOffset);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _initializing = false;
        _errorMessage = null;
      });
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  String _statusForCapture(HdrMode mode) {
    switch (mode) {
      case HdrMode.off:
        return 'Đang chụp ảnh...';
      case HdrMode.light:
        return 'Đang xử lý HDR Nhẹ...';
      case HdrMode.strong:
        return 'Đang xử lý HDR Mạnh...';
      case HdrMode.hardware:
        return 'Đang chụp HDR+...';
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      AppSnack.show(context, _errorMessage ?? 'Camera chưa sẵn sàng.');
      return;
    }

    final settings = XAestheticScope.of(context).settings;
    final lensDirection = controller.description.lensDirection;

    try {
      setState(() {
        _capturing = true;
        _captureStatus = _statusForCapture(settings.hdrMode);
      });

      var imagePath = '';
      if (settings.hdrMode == HdrMode.hardware) {
        imagePath = await _captureHardwareHdr(lensDirection, settings);
      } else {
        final file = await controller.takePicture();
        imagePath = file.path;
        if (settings.hdrMode != HdrMode.off) {
          imagePath = await SoftwareHdrProcessor.process(imagePath,
              mode: settings.hdrMode);
        }
      }

      imagePath =
          await AspectRatioProcessor.crop(imagePath, settings.aspectRatio);

      if (!mounted) {
        return;
      }
      XAestheticScope.of(context).setCurrentCapture(
        imagePath,
        metadata: CaptureMetadata.fromSettings(
          lensDirection: lensDirection,
          resolutionPreset: settings.resolutionPreset,
          hdrMode: settings.hdrMode,
          aspectRatio: settings.aspectRatio,
          exposureOffset: settings.exposureOffset,
          horizonAngle: _tiltDegrees,
          photoContext: settings.photoContext,
        ),
      );
      widget.onImageCaptured(imagePath);
    } catch (_) {
      if (mounted) {
        AppSnack.show(context, 'Không chụp được ảnh. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
          _captureStatus = '';
        });
      }
    }
  }

  Future<String> _captureHardwareHdr(
      CameraLensDirection lensDirection, CameraUserSettings settings) async {
    final controller = _cameraController;
    if (!_hardwareHdrAvailable) {
      final file = await controller!.takePicture();
      if (mounted) {
        AppSnack.show(context,
            'Thiết bị chưa hỗ trợ HDR phần cứng. Đã dùng HDR Mạnh thay thế.');
      }
      return SoftwareHdrProcessor.process(file.path, mode: HdrMode.strong);
    }

    try {
      await _detachAndDisposeCamera(showInitializing: true);
      final path =
          await _hardwareHdrBridge.capture(lensDirection: lensDirection);
      await _restoreCameraAfterNativeCapture(lensDirection, settings);

      if (await SoftwareHdrProcessor.isProbablyBlack(path)) {
        if (mounted) {
          AppSnack.show(
              context, 'HDR+ trả về ảnh quá tối. Đã dùng HDR Mạnh thay thế.');
        }
        final fallbackController = _cameraController;
        if (fallbackController == null ||
            !fallbackController.value.isInitialized) {
          return path;
        }
        final file = await fallbackController.takePicture();
        return SoftwareHdrProcessor.process(file.path, mode: HdrMode.strong);
      }

      return path;
    } on HardwareHdrUnavailableException catch (error) {
      await _restoreCameraAfterNativeCapture(lensDirection, settings);
      if (mounted) {
        AppSnack.show(context, '${error.message} Đã dùng HDR Mạnh thay thế.');
      }
      final fallbackController = _cameraController;
      if (fallbackController == null ||
          !fallbackController.value.isInitialized) {
        rethrow;
      }
      final file = await fallbackController.takePicture();
      return SoftwareHdrProcessor.process(file.path, mode: HdrMode.strong);
    }
  }

  Future<void> _restoreCameraAfterNativeCapture(
      CameraLensDirection lensDirection, CameraUserSettings settings) async {
    if (!mounted) {
      return;
    }

    final camera = _cameras.firstWhere(
      (item) => item.lensDirection == lensDirection,
      orElse: () => _cameras.isNotEmpty
          ? _cameras.first
          : throw CameraException(
              'no_camera', 'Không tìm thấy camera để khôi phục.'),
    );
    await _openCamera(camera, settings);
  }

  Future<void> _refreshHardwareHdrSupport(
      CameraLensDirection lensDirection) async {
    if (_checkingHardwareHdr) {
      return;
    }

    _checkingHardwareHdr = true;
    final supported =
        await _hardwareHdrBridge.isSupported(lensDirection: lensDirection);
    if (mounted) {
      setState(() => _hardwareHdrAvailable = supported);
    } else {
      _hardwareHdrAvailable = supported;
    }
    _checkingHardwareHdr = false;
  }

  void _startHorizonSensor() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream().listen(
      (event) {
        final rawDegrees = math.atan2(event.x, event.y) * 180 / math.pi;
        final calibrated = _normalizeDegrees(rawDegrees - _horizonCalibration);
        if ((calibrated - _tiltDegrees).abs() < 0.2) {
          return;
        }
        if (mounted) {
          setState(() => _tiltDegrees = calibrated);
        }
      },
      onError: (_) {
        // Một số môi trường desktop/test không có cảm biến gia tốc.
        // Khi đó chỉ giữ giá trị 0° để UI vẫn chạy được.
      },
    );
  }

  double _normalizeDegrees(double value) {
    var result = value;
    while (result > 45) {
      result -= 90;
    }
    while (result < -45) {
      result += 90;
    }
    return result;
  }

  void _calibrateHorizon() {
    _horizonCalibration += _tiltDegrees;
    setState(() => _tiltDegrees = 0);
    AppSnack.show(context, 'Đã hiệu chỉnh đường chân trời về 0° hiện tại.');
  }

  Future<void> _applyCameraCapabilities(
      CameraController controller, double exposureOffset) async {
    try {
      _minExposureOffset = await controller.getMinExposureOffset();
      _maxExposureOffset = await controller.getMaxExposureOffset();
      final offset = exposureOffset
          .clamp(_minExposureOffset, _maxExposureOffset)
          .toDouble();
      await controller.setExposureMode(ExposureMode.auto);
      await controller.setExposureOffset(offset);
    } catch (_) {
      _minExposureOffset = 0;
      _maxExposureOffset = 0;
    }
  }

  Future<void> _setExposureOffset(double value) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.setExposureOffset(
          value.clamp(_minExposureOffset, _maxExposureOffset).toDouble());
    } catch (_) {
      if (mounted) {
        AppSnack.show(
            context, 'Thiết bị này chưa hỗ trợ chỉnh phơi sáng thủ công.');
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      AppSnack.show(context, 'Thiết bị chỉ có một camera khả dụng.');
      return;
    }

    final current = _cameraController?.description;
    final next = _cameras.firstWhere(
      (item) => item.name != current?.name,
      orElse: () => _cameras.first,
    );
    final settings = XAestheticScope.of(context).settings;

    try {
      setState(() => _initializing = true);
      await _refreshHardwareHdrSupport(next.lensDirection);
      await _openCamera(next, settings);
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _errorMessage = 'Không đổi được camera.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return XScopeBuilder(
      builder: (context, app) {
        if (_lastResolutionPreset != null &&
            _lastResolutionPreset != app.settings.resolutionPreset &&
            !_initializing) {
          scheduleMicrotask(_initializeCamera);
        }

        return XBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: _CameraCanvas(
                  controller: _cameraController,
                  initializing: _initializing,
                  errorMessage: _errorMessage,
                  settings: app.settings,
                  tiltDegrees: _tiltDegrees,
                  onRetry: _initializeCamera,
                ),
              ),
              if (_capturing)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _CaptureBusyOverlay(message: _captureStatus),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SafeArea(
                  bottom: false,
                  child: _CameraTopBar(
                    onClose: widget.onClose,
                    onSettings: () => _openSettings(context, app),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CaptureControls(
                      latestPath: app.latestPhoto?.filePath,
                      capturing: _capturing,
                      onCapture: _capturePhoto,
                      onOpenLatestPhoto: () {
                        final latest = app.latestPhoto?.filePath;
                        if (latest == null) {
                          AppSnack.show(context,
                              'Chưa có ảnh nào trong thư viện ứng dụng.');
                          return;
                        }
                        widget.onOpenLatestPhoto(latest);
                      },
                      onSwitchCamera: _switchCamera,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSettings(BuildContext context, XAestheticController app) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CameraSettingsSheet(
        controller: app,
        minExposureOffset: _minExposureOffset,
        maxExposureOffset: _maxExposureOffset,
        onResolutionChanged: _initializeCamera,
        onExposureChanged: _setExposureOffset,
        onCalibrateHorizon: _calibrateHorizon,
        hardwareHdrAvailable: _hardwareHdrAvailable,
        hardwareHdrChecking: _checkingHardwareHdr,
      ),
    );
  }
}

class _CameraCanvas extends StatelessWidget {
  final CameraController? controller;
  final bool initializing;
  final String? errorMessage;
  final CameraUserSettings settings;
  final double tiltDegrees;
  final VoidCallback onRetry;

  const _CameraCanvas({
    required this.controller,
    required this.initializing,
    required this.errorMessage,
    required this.settings,
    required this.tiltDegrees,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final camera = controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (camera != null && camera.value.isInitialized)
          _CameraPreviewCover(controller: camera)
        else
          _CameraFallback(
              errorMessage: errorMessage,
              initializing: initializing,
              onRetry: onRetry),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: tokens.isDark ? 0.38 : 0.14),
                Colors.transparent,
                Colors.black.withValues(alpha: tokens.isDark ? 0.72 : 0.44),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        CustomPaint(
          painter: _CameraOverlayPainter(
            settings: settings,
            color: Colors.white,
            accent: tokens.primary,
          ),
        ),
        if (settings.showHorizon)
          Positioned(
              left: 20,
              right: 20,
              bottom: 142,
              child: _TiltIndicator(tiltDegrees: tiltDegrees)),
      ],
    );
  }
}

class _CameraPreviewCover extends StatelessWidget {
  final CameraController controller;

  const _CameraPreviewCover({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        if (previewSize == null) {
          return CameraPreview(controller);
        }
        final previewRatio = previewSize.height / previewSize.width;
        final screenRatio = constraints.maxWidth / constraints.maxHeight;
        return Transform.scale(
          scale: previewRatio / screenRatio,
          child: Center(child: CameraPreview(controller)),
        );
      },
    );
  }
}

class _CameraFallback extends StatelessWidget {
  final String? errorMessage;
  final bool initializing;
  final VoidCallback onRetry;

  const _CameraFallback(
      {required this.errorMessage,
      required this.initializing,
      required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _MockPortraitPainter(isDark: tokens.isDark)),
        if (initializing || errorMessage != null)
          Container(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.05),
            alignment: Alignment.center,
            child: XCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (initializing)
                        SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: tokens.primary))
                      else
                        Icon(Icons.camera_alt_outlined, color: tokens.primary),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          initializing ? 'Đang mở camera...' : errorMessage!,
                          style: TextStyle(
                              color: tokens.text, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  if (!initializing) ...[
                    const SizedBox(height: 12),
                    SecondaryButton(
                        label: 'Thử lại',
                        icon: Icons.refresh_rounded,
                        onPressed: onRetry),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CameraTopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSettings;

  const _CameraTopBar({required this.onClose, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _TopButton(icon: Icons.close_rounded, onTap: onClose),
          const Expanded(child: Center(child: XBrandText(fontSize: 20))),
          _TopButton(icon: Icons.settings_rounded, onTap: onSettings),
        ],
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color:
                tokens.surface.withValues(alpha: tokens.isDark ? 0.36 : 0.54),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white
                    .withValues(alpha: tokens.isDark ? 0.10 : 0.24)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _TiltIndicator extends StatelessWidget {
  final double tiltDegrees;

  const _TiltIndicator({required this.tiltDegrees});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final absTilt = tiltDegrees.abs();
    final color = absTilt <= 1.0
        ? tokens.positive
        : (absTilt <= 4.0 ? tokens.warning : Colors.redAccent);
    final label =
        '${tiltDegrees >= 0 ? '+' : ''}${tiltDegrees.toStringAsFixed(1)}°';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedRotation(
          turns: tiltDegrees / 360,
          duration: const Duration(milliseconds: 90),
          child: Row(
            children: [
              Expanded(
                  child: Container(
                      height: 2, color: color.withValues(alpha: 0.82))),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Expanded(
                  child: Container(
                      height: 2, color: color.withValues(alpha: 0.82))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.75)),
          ),
          child: Text(
            absTilt <= 1.0 ? 'Cân bằng • $label' : 'Nghiêng $label',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _CaptureBusyOverlay extends StatelessWidget {
  final String message;

  const _CaptureBusyOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Container(
      color: Colors.black.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: XCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        color: tokens.surface.withValues(alpha: tokens.isDark ? 0.86 : 0.92),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.8, color: tokens.primary)),
            const SizedBox(width: 12),
            Text(
              message.isEmpty ? 'Đang xử lý ảnh...' : message,
              style: TextStyle(color: tokens.text, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureControls extends StatelessWidget {
  final String? latestPath;
  final bool capturing;
  final VoidCallback onCapture;
  final VoidCallback onOpenLatestPhoto;
  final VoidCallback onSwitchCamera;

  const _CaptureControls({
    required this.latestPath,
    required this.capturing,
    required this.onCapture,
    required this.onOpenLatestPhoto,
    required this.onSwitchCamera,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ControlButton(
              icon: Icons.cameraswitch_rounded, onTap: onSwitchCamera),
          GestureDetector(
            onTap: onCapture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: capturing ? 74 : 84,
              height: capturing ? 74 : 84,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tokens.primary, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: tokens.primary.withValues(alpha: 0.28),
                      blurRadius: 22)
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                child: capturing
                    ? Padding(
                        padding: const EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: tokens.primary))
                    : null,
              ),
            ),
          ),
          _LatestPhotoButton(latestPath: latestPath, onTap: onOpenLatestPhoto),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class _LatestPhotoButton extends StatelessWidget {
  final String? latestPath;
  final VoidCallback onTap;

  const _LatestPhotoButton({required this.latestPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: latestPath == null
              ? const Icon(Icons.photo_library_outlined,
                  color: Colors.white, size: 27)
              : Image.file(
                  File(latestPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white,
                      size: 27),
                ),
        ),
      ),
    );
  }
}

class _CameraSettingsSheet extends StatelessWidget {
  final XAestheticController controller;
  final double minExposureOffset;
  final double maxExposureOffset;
  final Future<void> Function() onResolutionChanged;
  final Future<void> Function(double value) onExposureChanged;
  final VoidCallback onCalibrateHorizon;
  final bool hardwareHdrAvailable;
  final bool hardwareHdrChecking;

  const _CameraSettingsSheet({
    required this.controller,
    required this.minExposureOffset,
    required this.maxExposureOffset,
    required this.onResolutionChanged,
    required this.onExposureChanged,
    required this.onCalibrateHorizon,
    required this.hardwareHdrAvailable,
    required this.hardwareHdrChecking,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tokens = context.x;
        final settings = controller.settings;
        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: tokens.border),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                            color: tokens.muted.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999)))),
                const SizedBox(height: 18),
                Text('Cài đặt camera',
                    style: TextStyle(
                        color: tokens.text,
                        fontSize: 21,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                XCard(
                  padding: EdgeInsets.zero,
                  radius: 20,
                  child: Column(
                    children: [
                      _PhotoContextSelector(
                        value: settings.photoContext,
                        onChanged: (value) => controller.updateSettings(
                            settings.copyWith(photoContext: value)),
                      ),
                      Divider(color: tokens.border),
                      _SettingSwitch(
                          icon: Icons.grid_on_rounded,
                          title: 'Lưới 1/3',
                          value: settings.showGrid,
                          onChanged: (value) => controller.updateSettings(
                              settings.copyWith(showGrid: value))),
                      _SettingSwitch(
                          icon: Icons.horizontal_rule_rounded,
                          title: 'Đường chân trời',
                          value: settings.showHorizon,
                          onChanged: (value) => controller.updateSettings(
                              settings.copyWith(showHorizon: value))),
                      _SettingSwitch(
                          icon: Icons.person_outline_rounded,
                          title: 'Viền chủ thể',
                          value: settings.showSubjectOutline,
                          onChanged: (value) => controller.updateSettings(
                              settings.copyWith(showSubjectOutline: value))),
                      _SettingSwitch(
                          icon: Icons.crop_free_rounded,
                          title: 'Khung gợi ý',
                          value: settings.showSuggestionFrame,
                          onChanged: (value) => controller.updateSettings(
                              settings.copyWith(showSuggestionFrame: value))),
                      _HdrModeSelector(
                        value: settings.hdrMode,
                        hardwareAvailable: hardwareHdrAvailable,
                        checkingHardware: hardwareHdrChecking,
                        onChanged: (value) => controller
                            .updateSettings(settings.copyWith(hdrMode: value)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                XCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  radius: 20,
                  child: Column(
                    children: [
                      _AspectRatioSelector(
                        value: settings.aspectRatio,
                        onChanged: (value) => controller.updateSettings(
                            settings.copyWith(aspectRatio: value)),
                      ),
                      Divider(color: tokens.border),
                      Row(
                        children: [
                          Icon(Icons.high_quality_rounded,
                              color: tokens.primary),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text('Độ phân giải',
                                  style: TextStyle(
                                      color: tokens.text,
                                      fontWeight: FontWeight.w900))),
                          DropdownButton<ResolutionPreset>(
                            value: settings.resolutionPreset,
                            dropdownColor: tokens.surface,
                            borderRadius: BorderRadius.circular(14),
                            underline: const SizedBox.shrink(),
                            items: const [
                              ResolutionPreset.medium,
                              ResolutionPreset.high,
                              ResolutionPreset.veryHigh,
                              ResolutionPreset.ultraHigh,
                              ResolutionPreset.max,
                            ]
                                .map((item) => DropdownMenuItem(
                                    value: item, child: Text(item.label)))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              controller.updateSettings(
                                  settings.copyWith(resolutionPreset: value));
                              onResolutionChanged();
                            },
                          ),
                        ],
                      ),
                      Divider(color: tokens.border),
                      _ExposureSlider(
                        min: minExposureOffset,
                        max: maxExposureOffset,
                        value: settings.exposureOffset,
                        onChanged: (value) {
                          controller.updateSettings(
                              settings.copyWith(exposureOffset: value));
                          onExposureChanged(value);
                        },
                      ),
                      Divider(color: tokens.border),
                      _CalibrateHorizonButton(onCalibrate: onCalibrateHorizon),
                      Divider(color: tokens.border),
                      Row(
                        children: [
                          Icon(Icons.contrast_rounded, color: tokens.primary),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text('Giao diện',
                                  style: TextStyle(
                                      color: tokens.text,
                                      fontWeight: FontWeight.w900))),
                          SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('Dark'),
                                  icon: Icon(Icons.dark_mode_rounded)),
                              ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('Light'),
                                  icon: Icon(Icons.light_mode_rounded)),
                            ],
                            selected: {settings.themeMode},
                            onSelectionChanged: (selected) =>
                                controller.updateThemeMode(selected.first),
                            showSelectedIcon: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PhotoContextSelector extends StatelessWidget {
  final PhotoContext value;
  final ValueChanged<PhotoContext> onChanged;

  const _PhotoContextSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final visibleContexts = const [
      PhotoContext.auto,
      PhotoContext.general,
      PhotoContext.landscape,
      PhotoContext.street,
      PhotoContext.architecture,
      PhotoContext.food,
      PhotoContext.product,
      PhotoContext.macro,
      PhotoContext.animal,
      PhotoContext.night,
      PhotoContext.portrait,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_mosaic_rounded, color: tokens.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Ngữ cảnh chụp',
                      style: TextStyle(
                          color: tokens.text, fontWeight: FontWeight.w900))),
              Text(value.shortLabel,
                  style: TextStyle(
                      color: tokens.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleContexts.map((item) {
              final selected = item == value;
              return ChoiceChip(
                label: Text(item.shortLabel),
                selected: selected,
                onSelected: (_) => onChanged(item),
                selectedColor: tokens.primary,
                backgroundColor: tokens.surface2,
                side: BorderSide(
                    color: selected ? tokens.primary : tokens.border),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : tokens.text,
                  fontWeight: FontWeight.w900,
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(value.description,
              style: TextStyle(color: tokens.muted, fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }
}

class _AspectRatioSelector extends StatelessWidget {
  final CaptureAspectRatio value;
  final ValueChanged<CaptureAspectRatio> onChanged;

  const _AspectRatioSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.aspect_ratio_rounded, color: tokens.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Tỉ lệ khung ảnh',
                      style: TextStyle(
                          color: tokens.text, fontWeight: FontWeight.w900))),
              Text(value.label,
                  style: TextStyle(
                      color: tokens.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CaptureAspectRatio.values.map((item) {
              final selected = item == value;
              return ChoiceChip(
                label: Text(item.label),
                selected: selected,
                onSelected: (_) => onChanged(item),
                selectedColor: tokens.primary,
                backgroundColor: tokens.surface2,
                side: BorderSide(
                    color: selected ? tokens.primary : tokens.border),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : tokens.text,
                  fontWeight: FontWeight.w900,
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(value.description,
              style: TextStyle(color: tokens.muted, fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }
}

class _HdrModeSelector extends StatelessWidget {
  final HdrMode value;
  final bool hardwareAvailable;
  final bool checkingHardware;
  final ValueChanged<HdrMode> onChanged;

  const _HdrModeSelector({
    required this.value,
    required this.hardwareAvailable,
    required this.checkingHardware,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final statusText = checkingHardware
        ? 'Đang kiểm tra HDR phần cứng...'
        : hardwareAvailable
            ? 'Thiết bị hỗ trợ HDR phần cứng. Khi chụp sẽ dùng native Camera2 HDR.'
            : 'Thiết bị chưa báo hỗ trợ HDR phần cứng; chế độ HDR+ sẽ tự fallback sang HDR Mạnh.';
    final statusColor = hardwareAvailable ? tokens.positive : tokens.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hdr_auto_rounded, color: tokens.text),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'HDR',
                  style: TextStyle(
                      color: tokens.text, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                value.label,
                style: TextStyle(
                    color: tokens.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<HdrMode>(
            segments: const [
              ButtonSegment(value: HdrMode.off, label: Text('Tắt')),
              ButtonSegment(value: HdrMode.light, label: Text('Nhẹ')),
              ButtonSegment(value: HdrMode.strong, label: Text('Mạnh')),
              ButtonSegment(value: HdrMode.hardware, label: Text('HDR+')),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selected) => onChanged(selected.first),
          ),
          const SizedBox(height: 8),
          Text(
            value.description,
            style: TextStyle(color: tokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                if (checkingHardware)
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: statusColor))
                else
                  Icon(
                      hardwareAvailable
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(statusText,
                        style: TextStyle(
                            color: tokens.text.withValues(alpha: 0.82),
                            fontSize: 11.5,
                            height: 1.25))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExposureSlider extends StatelessWidget {
  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  const _ExposureSlider(
      {required this.min,
      required this.max,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final supported = max > min;
    final safeValue = supported ? value.clamp(min, max).toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.exposure_rounded, color: tokens.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Bù sáng',
                      style: TextStyle(
                          color: tokens.text, fontWeight: FontWeight.w900))),
              Text(supported ? safeValue.toStringAsFixed(1) : 'Không hỗ trợ',
                  style: TextStyle(
                      color: tokens.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ],
          ),
          if (supported)
            Slider(
              value: safeValue,
              min: min,
              max: max,
              divisions: ((max - min) * 2).round().clamp(1, 20),
              label: safeValue.toStringAsFixed(1),
              onChanged: onChanged,
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 6, bottom: 4),
              child: Text(
                  'Thiết bị hiện tại không trả về dải bù sáng thủ công.',
                  style: TextStyle(color: tokens.muted, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _CalibrateHorizonButton extends StatelessWidget {
  final VoidCallback onCalibrate;

  const _CalibrateHorizonButton({required this.onCalibrate});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.straighten_rounded, color: tokens.primary),
      title: Text('Hiệu chỉnh đường chân trời',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.w900)),
      subtitle: Text('Đặt tư thế máy hiện tại làm mốc 0°.',
          style: TextStyle(color: tokens.muted, fontSize: 12)),
      trailing: FilledButton(
        onPressed: onCalibrate,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Hiệu chỉnh'),
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch(
      {required this.icon,
      required this.title,
      this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: tokens.primary,
      activeTrackColor: tokens.primary.withValues(alpha: 0.35),
      secondary: Icon(icon, color: tokens.text),
      title: Text(title,
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.w800)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: TextStyle(color: tokens.muted, fontSize: 12)),
    );
  }
}

class _CameraOverlayPainter extends CustomPainter {
  final CameraUserSettings settings;
  final Color color;
  final Color accent;

  _CameraOverlayPainter(
      {required this.settings, required this.color, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final safeTop = 104.0;
    final safeBottom = 126.0;
    final available = Rect.fromLTWH(
        18, safeTop, size.width - 36, size.height - safeTop - safeBottom);
    final view = _compositionFrame(available, settings.aspectRatio);
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.46)
      ..strokeWidth = 1.0;

    if (settings.aspectRatio != CaptureAspectRatio.full) {
      final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.26);
      final maskPath = Path()
        ..addRect(Offset.zero & size)
        ..addRRect(RRect.fromRectAndRadius(view, const Radius.circular(30)))
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(maskPath, maskPaint);
      final framePaint = Paint()
        ..color = color.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15;
      canvas.drawRRect(
          RRect.fromRectAndRadius(view, const Radius.circular(30)), framePaint);
    }

    if (settings.showGrid) {
      canvas.drawLine(Offset(view.left + view.width / 3, view.top),
          Offset(view.left + view.width / 3, view.bottom), gridPaint);
      canvas.drawLine(Offset(view.left + view.width * 2 / 3, view.top),
          Offset(view.left + view.width * 2 / 3, view.bottom), gridPaint);
      canvas.drawLine(Offset(view.left, view.top + view.height / 3),
          Offset(view.right, view.top + view.height / 3), gridPaint);
      canvas.drawLine(Offset(view.left, view.top + view.height * 2 / 3),
          Offset(view.right, view.top + view.height * 2 / 3), gridPaint);
    }

    if (settings.showSuggestionFrame) {
      final dashPaint = Paint()
        ..color = color.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25;
      _drawDashedRRect(
          canvas,
          RRect.fromRectAndRadius(view.deflate(18), const Radius.circular(42)),
          dashPaint);
    }

    if (settings.showSubjectOutline) {
      final subject = Rect.fromLTWH(view.left + view.width * 0.47,
          view.top + view.height * 0.18, view.width * 0.34, view.height * 0.58);
      final subjectPaint = Paint()
        ..color = accent.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
          RRect.fromRectAndRadius(subject, const Radius.circular(36)),
          subjectPaint);
      final pointPaint = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6;
      final point =
          Offset(view.left + view.width * 2 / 3, view.top + view.height / 3);
      canvas.drawCircle(point, 11, pointPaint);
      canvas.drawCircle(point, 3.8, Paint()..color = accent);
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 10.0;
      const gap = 8.0;
      while (distance < metric.length) {
        canvas.drawPath(
            metric.extractPath(
                distance, math.min(distance + dash, metric.length)),
            paint);
        distance += dash + gap;
      }
    }
  }

  Rect _compositionFrame(Rect available, CaptureAspectRatio aspectRatio) {
    final targetRatio = aspectRatio.widthOverHeight;
    if (targetRatio == null) {
      return available;
    }

    final currentRatio = available.width / available.height;
    late double width;
    late double height;
    if (currentRatio > targetRatio) {
      height = available.height;
      width = height * targetRatio;
    } else {
      width = available.width;
      height = width / targetRatio;
    }

    return Rect.fromCenter(
        center: available.center, width: width, height: height);
  }

  @override
  bool shouldRepaint(covariant _CameraOverlayPainter oldDelegate) =>
      oldDelegate.settings != settings ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent;
}

class _MockPortraitPainter extends CustomPainter {
  final bool isDark;

  _MockPortraitPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = LinearGradient(
        colors: isDark
            ? const [Color(0xFF27313A), Color(0xFF0B1016)]
            : const [Color(0xFFDDE8D9), Color(0xFFF6F1E8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final street = Paint()
      ..color = isDark ? const Color(0xFF161B21) : const Color(0xFFD0D1C8);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.62)
        ..lineTo(size.width, size.height * 0.54)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      street,
    );

    for (var i = 0; i < 6; i++) {
      final x = size.width * (0.08 + i * 0.18);
      final h = size.height * (0.24 + (i % 3) * 0.06);
      final building = Paint()
        ..color = isDark
            ? Color.lerp(
                const Color(0xFF202A34), const Color(0xFF0E141A), i / 6)!
            : Color.lerp(
                const Color(0xFFE1E2DA), const Color(0xFFC9CEC4), i / 6)!;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, size.height * 0.18, size.width * 0.16, h),
              const Radius.circular(12)),
          building);
    }

    final skin = Paint()
      ..color = isDark ? const Color(0xFFE2B99E) : const Color(0xFFD7A989);
    final hair = Paint()
      ..color = isDark ? const Color(0xFF0A0C0E) : const Color(0xFF2A211E);
    final jacket = Paint()
      ..color = isDark ? const Color(0xFF0C1117) : const Color(0xFF202A2F);

    final centerX = size.width * 0.58;
    final bodyTop = size.height * 0.44;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - size.width * 0.15, bodyTop, size.width * 0.28,
              size.height * 0.38),
          const Radius.circular(44)),
      jacket,
    );
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(centerX, size.height * 0.33),
            width: size.width * 0.16,
            height: size.width * 0.20),
        skin);
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(centerX - size.width * 0.01, size.height * 0.30),
            width: size.width * 0.18,
            height: size.width * 0.15),
        math.pi,
        math.pi * 1.1,
        false,
        hair
          ..strokeWidth = 24
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _MockPortraitPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
