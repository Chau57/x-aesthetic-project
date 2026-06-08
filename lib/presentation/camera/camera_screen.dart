import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../app/x_aesthetic_controller.dart';
import '../../core/camera/horizon_math.dart';
import '../../domain/entities/camera_settings.dart';
import '../../domain/entities/captured_photo.dart';
import '../../services/camera/aspect_ratio_processor.dart';
import '../../services/camera/hardware_hdr_camera_bridge.dart';
import '../../services/camera/software_hdr_processor.dart';
import '../shared/x_theme.dart';
import '../shared/x_widgets.dart';

enum _XiaomiCameraMode { pro, photo }

extension _XiaomiCameraModeLabel on _XiaomiCameraMode {
  String get label {
    switch (this) {
      case _XiaomiCameraMode.pro:
        return 'Chuyên nghiệp';
      case _XiaomiCameraMode.photo:
        return 'Nghiệp dư';
    }
  }
}

// Sensor values and the first Android layout passes may briefly report
// unusual sizes/angles. Keep these helpers defensive so camera UI never
// crashes while CameraX is attaching its SurfaceView.
double _safeClampDouble(double value, double min, double max) {
  if (!value.isFinite) {
    value = 0;
  }
  if (!min.isFinite) {
    min = 0;
  }
  if (!max.isFinite || max < min) {
    return min;
  }
  return value.clamp(min, max).toDouble();
}

class CameraScreen extends StatefulWidget {
  final ValueChanged<String> onImageCaptured;
  final ValueChanged<String> onOpenLatestPhoto;
  final VoidCallback onClose;
  final bool isActive;

  const CameraScreen({
    required this.onImageCaptured,
    required this.onOpenLatestPhoto,
    required this.onClose,
    required this.isActive,
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
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _tiltDegrees = 0;
  double _minExposureOffset = 0;
  double _maxExposureOffset = 0;
  Offset? _focusPoint;
  Timer? _focusPointTimer;
  bool _showExposureDial = false;
  bool _hardwareHdrAvailable = false;
  bool _checkingHardwareHdr = false;
  bool _disposed = false;
  int _cameraSessionId = 0;
  int _lastTiltUpdateMs = 0;
  String _captureStatus = '';
  bool _settingsPanelOpen = false;
  Timer? _countdownTimer;
  int _timerSeconds = 0;
  int _countdownRemaining = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _screenFlashActive = false;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoom = 1.0;
  _XiaomiCameraMode _activeMode = _XiaomiCameraMode.photo;
  final HardwareHdrCameraBridge _hardwareHdrBridge =
      const HardwareHdrCameraBridge();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      _startHorizonSensor();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) {
        _initializeCamera();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _cameraSessionId++;
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSubscription?.cancel();
    _focusPointTimer?.cancel();
    _countdownTimer?.cancel();
    final controller = _cameraController;
    _cameraController = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) {
      return;
    }

    if (widget.isActive) {
      _startHorizonSensor();
      unawaited(
        _initializeCamera(
          preferredLensDirection: _cameraController?.description.lensDirection,
        ),
      );
    } else {
      unawaited(_accelerometerSubscription?.cancel());
      _accelerometerSubscription = null;
      unawaited(_detachAndDisposeCamera());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) {
      return;
    }

    if (!widget.isActive) {
      if (state != AppLifecycleState.resumed) {
        unawaited(_detachAndDisposeCamera());
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_accelerometerSubscription?.cancel());
      _accelerometerSubscription = null;
      unawaited(_detachAndDisposeCamera());
      return;
    }

    if (state == AppLifecycleState.resumed && !_capturing) {
      _startHorizonSensor();
      unawaited(
        _initializeCamera(
          preferredLensDirection: _cameraController?.description.lensDirection,
        ),
      );
    }
  }

  Future<void> _detachAndDisposeCamera({
    bool showInitializing = false,
    bool invalidateSession = true,
  }) async {
    if (invalidateSession) {
      _cameraSessionId++;
    }

    final controller = _cameraController;
    if (controller == null) {
      if (mounted && showInitializing && !_initializing) {
        setState(() => _initializing = true);
      }
      return;
    }

    if (mounted && !_disposed) {
      setState(() {
        if (identical(_cameraController, controller)) {
          _cameraController = null;
        }
        _initializing = showInitializing;
      });

      // Let Flutter rebuild one frame without CameraPreview before disposing.
      // Otherwise CameraPreview may try to render a disposed CameraController,
      // especially when HDR+ temporarily releases the Flutter camera for native Camera2.
      await WidgetsBinding.instance.endOfFrame;
    } else if (identical(_cameraController, controller)) {
      _cameraController = null;
    }

    try {
      await controller.dispose();
    } catch (error, stackTrace) {
      debugPrint('Camera dispose failed: $error\n$stackTrace');
      // Some Android camera backends throw if the lifecycle already closed the
      // underlying surface. Disposal should be best-effort and never crash UI.
    }
  }

  Future<void> _initializeCamera({
    CameraLensDirection? preferredLensDirection,
  }) async {
    if (!mounted || _disposed || _capturing || !widget.isActive) {
      return;
    }

    final sessionId = ++_cameraSessionId;
    final settings = XAestheticScope.of(
      context,
    ).settings.copyWith(resolutionPreset: ResolutionPreset.max);
    setState(() {
      _initializing = true;
      _errorMessage = null;
    });

    try {
      final cameras = await availableCameras();
      if (!_isActiveSession(sessionId)) {
        return;
      }
      if (cameras.isEmpty) {
        throw CameraException(
          'no_camera',
          'Không tìm thấy camera khả dụng trên thiết bị này.',
        );
      }
      _cameras = cameras;

      final targetLens = preferredLensDirection ??
          _cameraController?.description.lensDirection ??
          CameraLensDirection.back;
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == targetLens,
        orElse: () => cameras.first,
      );
      await _refreshHardwareHdrSupport(camera.lensDirection, sessionId);
      if (!_isActiveSession(sessionId)) {
        return;
      }
      await _openCamera(camera, settings, sessionId: sessionId);
    } on CameraException catch (error) {
      if (!_isActiveSession(sessionId)) {
        return;
      }
      setState(() {
        _initializing = false;
        _errorMessage = error.description ?? 'Không thể khởi tạo camera.';
      });
    } catch (error, stackTrace) {
      debugPrint('Camera initialization failed: $error\n$stackTrace');
      if (!_isActiveSession(sessionId)) {
        return;
      }
      setState(() {
        _initializing = false;
        _errorMessage =
            'Camera chưa khả dụng trên môi trường hiện tại. Trên Linux desktop có thể chỉ xem được UI, hãy chạy trên Android/iOS để chụp thật.';
      });
    }
  }

  bool _isActiveSession(int sessionId) {
    return mounted && !_disposed && sessionId == _cameraSessionId;
  }

  Future<void> _openCamera(
    CameraDescription camera,
    CameraUserSettings settings, {
    required int sessionId,
  }) async {
    await _detachAndDisposeCamera(
      showInitializing: true,
      invalidateSession: false,
    );
    if (!_isActiveSession(sessionId)) {
      return;
    }

    final controller = CameraController(
      camera,
      settings.resolutionPreset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      if (!_isActiveSession(sessionId)) {
        await controller.dispose();
        return;
      }
      await _applyCameraCapabilities(controller, settings.exposureOffset);
      if (!_isActiveSession(sessionId)) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _initializing = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Camera open failed: $error\n$stackTrace');
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
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing ||
        _initializing) {
      AppSnack.show(context, _errorMessage ?? 'Camera chưa sẵn sàng.');
      return;
    }

    final app = XAestheticScope.of(context);
    final settings = app.settings.copyWith(
      resolutionPreset: ResolutionPreset.max,
    );
    final lensDirection = controller.description.lensDirection;
    final captureSessionId = _cameraSessionId;

    final useManualFlash =
        _flashMode == FlashMode.always || _flashMode == FlashMode.torch;
    final isFrontCamera = lensDirection == CameraLensDirection.front;

    var backTorchEnabled = false;
    try {
      setState(() {
        _capturing = true;
        _captureStatus = _statusForCapture(settings.hdrMode);
      });

      // Screen flash for front camera.
      if (useManualFlash && isFrontCamera) {
        if (mounted && !_disposed) {
          setState(() => _screenFlashActive = true);
        }
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // Torch flash for back camera: turn on before capturing.
      if (useManualFlash && !isFrontCamera) {
        try {
          await controller.setFlashMode(FlashMode.torch);
          backTorchEnabled = true;
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (error, stackTrace) {
          debugPrint('Torch enable failed: $error\n$stackTrace');
        }
      }

      var imagePath = '';
      if (settings.hdrMode == HdrMode.hardware) {
        imagePath = await _captureHardwareHdr(
          lensDirection,
          settings,
          sessionId: captureSessionId,
        );
      } else {
        if (!_isActiveSession(captureSessionId)) {
          return;
        }
        final file = await controller.takePicture();
        imagePath = file.path;
        if (settings.hdrMode != HdrMode.off) {
          imagePath = await SoftwareHdrProcessor.process(
            imagePath,
            mode: settings.hdrMode,
          );
        }
      }

      // Turn off torch after capture.
      if (useManualFlash && !isFrontCamera) {
        try {
          await controller.setFlashMode(FlashMode.off);
          backTorchEnabled = false;
        } catch (error, stackTrace) {
          debugPrint('Torch disable after capture failed: $error\n$stackTrace');
        }
      }

      imagePath = await AspectRatioProcessor.crop(
        imagePath,
        settings.aspectRatio,
      );

      if (!_isActiveSession(captureSessionId)) {
        return;
      }
      app.setCurrentCapture(
        imagePath,
        metadata: CaptureMetadata.fromSettings(
          lensDirection: lensDirection,
          resolutionPreset: settings.resolutionPreset,
          hdrMode: settings.hdrMode,
          aspectRatio: settings.aspectRatio,
          exposureOffset: settings.exposureOffset,
          horizonAngle: horizonLevelErrorDegrees(_tiltDegrees),
          photoContext: settings.photoContext,
        ),
      );
      widget.onImageCaptured(imagePath);
    } catch (error, stackTrace) {
      debugPrint('Photo capture failed: $error\n$stackTrace');
      if (mounted && !_disposed) {
        AppSnack.show(context, 'Không chụp được ảnh. Vui lòng thử lại.');
      }
    } finally {
      if (backTorchEnabled) {
        final activeController = _cameraController;
        if (activeController != null && activeController.value.isInitialized) {
          try {
            await activeController.setFlashMode(FlashMode.off);
          } catch (error, stackTrace) {
            debugPrint('Torch reset in finally failed: $error\n$stackTrace');
          }
        }
      }
      if (mounted && !_disposed) {
        setState(() {
          _capturing = false;
          _captureStatus = '';
          _screenFlashActive = false;
        });
      }
    }
  }

  Future<String> _captureHardwareHdr(
    CameraLensDirection lensDirection,
    CameraUserSettings settings, {
    required int sessionId,
  }) async {
    final controller = _cameraController;
    if (!_hardwareHdrAvailable) {
      final file = await controller!.takePicture();
      if (mounted && !_disposed) {
        AppSnack.show(
          context,
          'Thiết bị chưa hỗ trợ HDR phần cứng. Đã dùng HDR Mạnh thay thế.',
        );
      }
      return SoftwareHdrProcessor.process(file.path, mode: HdrMode.strong);
    }

    try {
      await _detachAndDisposeCamera(
        showInitializing: true,
        invalidateSession: false,
      );
      final path = await _hardwareHdrBridge.capture(
        lensDirection: lensDirection,
      );
      await _restoreCameraAfterNativeCapture(
        lensDirection,
        settings,
        sessionId: sessionId,
      );

      if (await SoftwareHdrProcessor.isProbablyBlack(path)) {
        if (mounted && !_disposed) {
          AppSnack.show(
            context,
            'HDR+ trả về ảnh quá tối. Đã dùng HDR Mạnh thay thế.',
          );
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
      await _restoreCameraAfterNativeCapture(
        lensDirection,
        settings,
        sessionId: sessionId,
      );
      if (mounted && !_disposed) {
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
    CameraLensDirection lensDirection,
    CameraUserSettings settings, {
    required int sessionId,
  }) async {
    if (!_isActiveSession(sessionId)) {
      return;
    }

    final camera = _cameras.firstWhere(
      (item) => item.lensDirection == lensDirection,
      orElse: () => _cameras.isNotEmpty
          ? _cameras.first
          : throw CameraException(
              'no_camera',
              'Không tìm thấy camera để khôi phục.',
            ),
    );
    await _openCamera(camera, settings, sessionId: sessionId);
  }

  Future<void> _refreshHardwareHdrSupport(
    CameraLensDirection lensDirection, [
    int? sessionId,
  ]) async {
    if (_checkingHardwareHdr) {
      return;
    }

    _checkingHardwareHdr = true;
    try {
      final supported = await _hardwareHdrBridge.isSupported(
        lensDirection: lensDirection,
      );
      if (sessionId != null && !_isActiveSession(sessionId)) {
        return;
      }
      if (mounted && !_disposed) {
        setState(() => _hardwareHdrAvailable = supported);
      } else {
        _hardwareHdrAvailable = supported;
      }
    } catch (error, stackTrace) {
      debugPrint('Hardware HDR support check failed: $error\n$stackTrace');
      if (sessionId != null && !_isActiveSession(sessionId)) {
        return;
      }
      if (mounted && !_disposed) {
        setState(() => _hardwareHdrAvailable = false);
      } else {
        _hardwareHdrAvailable = false;
      }
    } finally {
      _checkingHardwareHdr = false;
    }
  }

  void _startHorizonSensor() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream().listen(
      (event) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastTiltUpdateMs < 66) {
          return;
        }

        // Store raw device roll. Rendering reduces it to the small error around
        // the nearest level axis, then rotates the horizon line in the opposite
        // direction so it stays parallel to the physical ground.
        final rollDegrees = deviceRollDegreesFromAccelerometer(
          x: event.x,
          y: event.y,
        );
        if (normalizeDegrees180(rollDegrees - _tiltDegrees).abs() < 0.6) {
          return;
        }
        _lastTiltUpdateMs = now;
        if (mounted && !_disposed) {
          setState(() => _tiltDegrees = rollDegrees);
        }
      },
      onError: (_) {
        // Một số môi trường desktop/test không có cảm biến gia tốc.
        // Khi đó chỉ giữ giá trị 0° để UI vẫn chạy được.
      },
    );
  }

  Future<void> _applyCameraCapabilities(
    CameraController controller,
    double exposureOffset,
  ) async {
    try {
      _minExposureOffset = await controller.getMinExposureOffset();
      _maxExposureOffset = await controller.getMaxExposureOffset();
      final offset = exposureOffset
          .clamp(_minExposureOffset, _maxExposureOffset)
          .toDouble();
      await controller.setExposureMode(ExposureMode.auto);
      await controller.setExposureOffset(offset);
    } catch (error, stackTrace) {
      debugPrint('Camera capability apply failed: $error\n$stackTrace');
      _minExposureOffset = 0;
      _maxExposureOffset = 0;
    }

    try {
      _minZoomLevel = await controller.getMinZoomLevel();
      _maxZoomLevel = await controller.getMaxZoomLevel();
      _currentZoom =
          _currentZoom.clamp(_minZoomLevel, _maxZoomLevel).toDouble();
      await controller.setZoomLevel(_currentZoom);
    } catch (error, stackTrace) {
      debugPrint('Camera zoom capability apply failed: $error\n$stackTrace');
      _minZoomLevel = 1.0;
      _maxZoomLevel = 1.0;
      _currentZoom = 1.0;
    }

    unawaited(_applyFlashMode(_flashMode));
  }

  Future<void> _applyFlashMode(FlashMode mode) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.setFlashMode(mode);
    } catch (error, stackTrace) {
      debugPrint('Flash mode apply failed: $error\n$stackTrace');
      // Flash is not available on every lens/device. Keep UI responsive.
    }
  }

  void _cycleFlashMode() {
    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      FlashMode.torch => FlashMode.off,
    };
    setState(() => _flashMode = next);
    unawaited(_applyFlashMode(next));
    final label = switch (next) {
      FlashMode.off => 'Tắt',
      FlashMode.auto => 'Tự động',
      FlashMode.always => 'Bật',
      FlashMode.torch => 'Torch',
    };
    AppSnack.show(context, 'Đèn flash: $label');
  }

  IconData get _flashIcon {
    return switch (_flashMode) {
      FlashMode.off => Icons.flash_off_rounded,
      FlashMode.auto => Icons.flash_auto_rounded,
      FlashMode.always => Icons.flash_on_rounded,
      FlashMode.torch => Icons.highlight_rounded,
    };
  }

  Future<void> _setZoomLevel(double zoom) async {
    final controller = _cameraController;
    final safeZoom = zoom.clamp(_minZoomLevel, _maxZoomLevel).toDouble();
    setState(() => _currentZoom = safeZoom);
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.setZoomLevel(safeZoom);
    } catch (error, stackTrace) {
      debugPrint('Zoom level apply failed: $error\n$stackTrace');
      // Some cameras expose limited zoom ranges. Ignore and keep the preview alive.
    }
  }

  void _setTimerSeconds(int seconds) {
    setState(() => _timerSeconds = seconds.clamp(0, 60));
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    if (mounted && !_disposed) {
      setState(() => _countdownRemaining = 0);
    }
  }

  void _handleShutterPressed() {
    if (_countdownRemaining > 0) {
      _cancelCountdown();
      return;
    }
    if (_timerSeconds <= 0) {
      unawaited(_capturePhoto());
      return;
    }

    _countdownTimer?.cancel();
    setState(() => _countdownRemaining = _timerSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _disposed) {
        timer.cancel();
        return;
      }
      if (_countdownRemaining <= 1) {
        timer.cancel();
        setState(() => _countdownRemaining = 0);
        unawaited(_capturePhoto());
      } else {
        setState(() => _countdownRemaining--);
      }
    });
  }

  void _handleViewfinderTap(TapUpDetails details, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    _settingsPanelOpen = false;
    final local = Offset(
      details.localPosition.dx.clamp(0.0, size.width),
      details.localPosition.dy.clamp(0.0, size.height),
    );
    final point = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );

    _focusPointTimer?.cancel();
    setState(() {
      _focusPoint = point;
    });
    _focusPointTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && !_disposed) {
        setState(() => _focusPoint = null);
      }
    });
    unawaited(_setMeteringPoint(point));
  }

  Future<void> _setExposureOffset(double value) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final range = _effectiveExposureRange;
    try {
      await controller.setExposureOffset(
        value.clamp(range.start, range.end).toDouble(),
      );
    } catch (error, stackTrace) {
      debugPrint('Exposure offset apply failed: $error\n$stackTrace');
      return;
    }
  }

  void _toggleExposureDial() {
    setState(() => _showExposureDial = !_showExposureDial);
  }

  void _updateExposureOffset(double value) {
    final range = _effectiveExposureRange;
    final safeValue = value.clamp(range.start, range.end).toDouble();
    final app = XAestheticScope.of(context);
    app.updateSettings(app.settings.copyWith(exposureOffset: safeValue));
    unawaited(_setExposureOffset(safeValue));
  }

  ({double start, double end}) get _effectiveExposureRange {
    if (_maxExposureOffset > _minExposureOffset) {
      return (
        start: _minExposureOffset.clamp(-2.0, 0.0).toDouble(),
        end: _maxExposureOffset.clamp(0.0, 2.0).toDouble(),
      );
    }
    return (start: -2.0, end: 2.0);
  }

  Future<void> _setMeteringPoint(Offset point) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } catch (error, stackTrace) {
      debugPrint('Focus/exposure point apply failed: $error\n$stackTrace');
      // Một số thiết bị chỉ hỗ trợ focus/exposure tự động toàn khung.
    }
  }

  Future<void> _switchCamera() async {
    if (_capturing || _initializing) {
      return;
    }
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
      final sessionId = ++_cameraSessionId;
      setState(() => _initializing = true);
      await _refreshHardwareHdrSupport(next.lensDirection, sessionId);
      if (!_isActiveSession(sessionId)) {
        return;
      }
      await _openCamera(next, settings, sessionId: sessionId);
    } catch (error, stackTrace) {
      debugPrint('Camera switch failed: $error\n$stackTrace');
      if (mounted && !_disposed) {
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
        final isFull = app.settings.aspectRatio == CaptureAspectRatio.full;
        return ColoredBox(
          color: Colors.black,
          child: SafeArea(
            child: isFull
                ? _buildFullXiaomiLayout(context, app)
                : _buildNormalXiaomiLayout(context, app),
          ),
        );
      },
    );
  }

  Widget _buildFullXiaomiLayout(
    BuildContext context,
    XAestheticController app,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _buildXiaomiViewport(app, isFull: true)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
            child: _buildXiaomiTopBar(app, overlay: true),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xDD000000), Colors.transparent],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildXiaomiViewportControls(app),
                ),
                const SizedBox(height: 14),
                _buildXiaomiBottomDeck(app, overlay: true),
              ],
            ),
          ),
        ),
        _buildTransientOverlays(),
      ],
    );
  }

  Widget _buildNormalXiaomiLayout(
    BuildContext context,
    XAestheticController app,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: const Color(0xFF0D0D0D),
          child: _buildXiaomiViewport(app, isFull: false),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
            child: _buildXiaomiTopBar(app, overlay: true),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xDD000000), Colors.transparent],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildXiaomiViewportControls(app),
                ),
                const SizedBox(height: 14),
                _buildXiaomiBottomDeck(app, overlay: true),
              ],
            ),
          ),
        ),
        _buildTransientOverlays(),
      ],
    );
  }

  Widget _buildXiaomiViewportControls(XAestheticController app) {
    return _XiaomiViewportControls(
      currentZoom: _currentZoom,
      minZoom: _minZoomLevel,
      maxZoom: _maxZoomLevel,
      evDialOpen: _showExposureDial,
      onExposureToggle: _toggleExposureDial,
      onZoomChanged: (value) => unawaited(_setZoomLevel(value)),
    );
  }

  Widget _buildXiaomiViewport(
    XAestheticController app, {
    required bool isFull,
  }) {
    return _XiaomiCameraViewport(
      controller: _cameraController,
      initializing: _initializing,
      errorMessage: _errorMessage,
      settings: app.settings,
      isFull: isFull,
      tiltDegrees: _tiltDegrees,
      focusPoint: _focusPoint,
      exposureValue: app.settings.exposureOffset,
      exposureMin: _effectiveExposureRange.start,
      exposureMax: _effectiveExposureRange.end,
      countdownRemaining: _countdownRemaining,
      onTapUp: _handleViewfinderTap,
      onRetry: () => unawaited(_initializeCamera()),
      onExposureChanged: _updateExposureOffset,
    );
  }

  Widget _buildXiaomiTopBar(XAestheticController app, {bool overlay = false}) {
    return _XiaomiTopControlBar(
      settings: app.settings,
      settingsPanelOpen: _settingsPanelOpen,
      flashIcon: _flashIcon,
      flashActive: _flashMode != FlashMode.off,
      timerSeconds: _timerSeconds,
      hardwareHdrAvailable: _hardwareHdrAvailable,
      hardwareHdrChecking: _checkingHardwareHdr,
      overlay: overlay,
      onClose: widget.onClose,
      onToggleFlash: _cycleFlashMode,
      onToggleSettings: () =>
          setState(() => _settingsPanelOpen = !_settingsPanelOpen),
      onAspectRatioChanged: (value) => app.updateSettings(
        app.settings.copyWith(aspectRatio: value),
      ),
      onTimerChanged: _setTimerSeconds,
      onHdrModeChanged: (value) => app.updateSettings(
        app.settings.copyWith(hdrMode: value),
      ),
      onThemeModeChanged: app.updateThemeMode,
      onGridChanged: (value) => app.updateSettings(
        app.settings.copyWith(showGrid: value),
      ),
      onHorizonChanged: (value) => app.updateSettings(
        app.settings.copyWith(showHorizon: value),
      ),
      onSubjectOutlineChanged: (value) => app.updateSettings(
        app.settings.copyWith(showSubjectOutline: value),
      ),
    );
  }

  Widget _buildXiaomiBottomDeck(
    XAestheticController app, {
    required bool overlay,
  }) {
    final latestPath = app.latestPhoto?.filePath;
    return _XiaomiBottomDeck(
      settings: app.settings,
      overlay: overlay,
      activeMode: _activeMode,
      capturing: _capturing,
      evDialOpen: _showExposureDial,
      exposureValue: app.settings.exposureOffset,
      exposureMin: _effectiveExposureRange.start,
      exposureMax: _effectiveExposureRange.end,
      countdownRemaining: _countdownRemaining,
      latestPath: latestPath,
      onExposureChanged: _updateExposureOffset,
      onExposureReset: () => _updateExposureOffset(0),
      onModeChanged: (mode) => setState(() => _activeMode = mode),
      onCapture: _handleShutterPressed,
      onOpenLatestPhoto: () {
        if (latestPath == null) {
          AppSnack.show(context, 'Chưa có ảnh nào trong thư viện ứng dụng.');
          return;
        }
        widget.onOpenLatestPhoto(latestPath);
      },
      onSwitchCamera: _switchCamera,
    );
  }

  Widget _buildTransientOverlays() {
    if (!_capturing && !_screenFlashActive) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        if (_screenFlashActive)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.95)),
            ),
          ),
        if (_capturing)
          Positioned.fill(
            child: IgnorePointer(
              child: _CaptureBusyOverlay(message: _captureStatus),
            ),
          ),
      ],
    );
  }
}

class _XiaomiTopControlBar extends StatelessWidget {
  final CameraUserSettings settings;
  final bool settingsPanelOpen;
  final IconData flashIcon;
  final bool flashActive;
  final int timerSeconds;
  final bool hardwareHdrAvailable;
  final bool hardwareHdrChecking;
  final bool overlay;
  final VoidCallback onClose;
  final VoidCallback onToggleFlash;
  final VoidCallback onToggleSettings;
  final ValueChanged<CaptureAspectRatio> onAspectRatioChanged;
  final ValueChanged<int> onTimerChanged;
  final ValueChanged<HdrMode> onHdrModeChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<bool> onGridChanged;
  final ValueChanged<bool> onHorizonChanged;
  final ValueChanged<bool> onSubjectOutlineChanged;

  const _XiaomiTopControlBar({
    required this.settings,
    required this.settingsPanelOpen,
    required this.flashIcon,
    required this.flashActive,
    required this.timerSeconds,
    required this.hardwareHdrAvailable,
    required this.hardwareHdrChecking,
    this.overlay = false,
    required this.onClose,
    required this.onToggleFlash,
    required this.onToggleSettings,
    required this.onAspectRatioChanged,
    required this.onTimerChanged,
    required this.onHdrModeChanged,
    required this.onThemeModeChanged,
    required this.onGridChanged,
    required this.onHorizonChanged,
    required this.onSubjectOutlineChanged,
  });

  bool get _isDark => settings.themeMode != ThemeMode.light || overlay;

  @override
  Widget build(BuildContext context) {
    final mainBg = overlay
        ? Colors.transparent
        : (_isDark ? Colors.black : const Color(0xFFF2F2F7));
    final panelBg = overlay
        ? const Color(0xCC161616)
        : (_isDark ? const Color(0xFF161616) : const Color(0xFFEBEBEF));
    final fg = _isDark ? Colors.white : Colors.black;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 24,
          padding: const EdgeInsets.only(right: 16),
          alignment: Alignment.centerRight,
          color: mainBg,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF00FF66),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(
          color: mainBg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              _XiaomiIconButton(
                icon: Icons.close_rounded,
                color: fg,
                onTap: onClose,
              ),
              const Spacer(),
              _XiaomiIconButton(
                icon: flashIcon,
                color: flashActive ? const Color(0xFFFFCC00) : fg,
                onTap: onToggleFlash,
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleSettings,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedRotation(
                    turns: settingsPanelOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: fg, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: settingsPanelOpen
                ? SizedBox(
                    key: const ValueKey('settings-panel'),
                    width: double.infinity,
                    child: ColoredBox(
                      color: panelBg,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: _XiaomiSettingsPanel(
                          settings: settings,
                          timerSeconds: timerSeconds,
                          hardwareHdrAvailable: hardwareHdrAvailable,
                          hardwareHdrChecking: hardwareHdrChecking,
                          onAspectRatioChanged: onAspectRatioChanged,
                          onTimerChanged: onTimerChanged,
                          onHdrModeChanged: onHdrModeChanged,
                          onThemeModeChanged: onThemeModeChanged,
                          onGridChanged: onGridChanged,
                          onHorizonChanged: onHorizonChanged,
                          onSubjectOutlineChanged: onSubjectOutlineChanged,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(
                    key: ValueKey('settings-closed'),
                    width: double.infinity,
                    height: 0,
                  ),
          ),
        ),
      ],
    );
  }
}

class _XiaomiSettingsPanel extends StatelessWidget {
  final CameraUserSettings settings;
  final int timerSeconds;
  final bool hardwareHdrAvailable;
  final bool hardwareHdrChecking;
  final ValueChanged<CaptureAspectRatio> onAspectRatioChanged;
  final ValueChanged<int> onTimerChanged;
  final ValueChanged<HdrMode> onHdrModeChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<bool> onGridChanged;
  final ValueChanged<bool> onHorizonChanged;
  final ValueChanged<bool> onSubjectOutlineChanged;

  const _XiaomiSettingsPanel({
    required this.settings,
    required this.timerSeconds,
    required this.hardwareHdrAvailable,
    required this.hardwareHdrChecking,
    required this.onAspectRatioChanged,
    required this.onTimerChanged,
    required this.onHdrModeChanged,
    required this.onThemeModeChanged,
    required this.onGridChanged,
    required this.onHorizonChanged,
    required this.onSubjectOutlineChanged,
  });

  bool get _isDark => settings.themeMode != ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    final labelColor = _isDark ? Colors.grey : Colors.grey.shade700;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _XiaomiSectionLabel('Tỷ lệ khung hình', color: labelColor),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final item in CaptureAspectRatio.values)
              Expanded(
                child: _XiaomiPill(
                  label: item.label,
                  selected: settings.aspectRatio == item,
                  isDark: _isDark,
                  onTap: () => onAspectRatioChanged(item),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _XiaomiSectionLabel('Hẹn giờ chụp', color: labelColor),
        const SizedBox(height: 8),
        Row(
          children: [
            _XiaomiIconPill(
              icon: Icons.timer_off_rounded,
              label: 'Tắt',
              selected: timerSeconds == 0,
              isDark: _isDark,
              onTap: () => onTimerChanged(0),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _XiaomiStepper(
                value: timerSeconds,
                isDark: _isDark,
                onChanged: onTimerChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _XiaomiSectionLabel('HDR', color: labelColor),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _XiaomiIconPill(
                          icon: Icons.hdr_off_rounded,
                          label: 'Tắt',
                          selected: settings.hdrMode == HdrMode.off,
                          isDark: _isDark,
                          onTap: () => onHdrModeChanged(HdrMode.off),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _XiaomiIconPill(
                          icon: hardwareHdrChecking
                              ? Icons.hourglass_top_rounded
                              : (hardwareHdrAvailable
                                  ? Icons.hdr_auto_rounded
                                  : Icons.hdr_on_rounded),
                          label: hardwareHdrAvailable ? 'HDR+' : 'Mạnh',
                          selected: settings.hdrMode != HdrMode.off,
                          isDark: _isDark,
                          onTap: () => onHdrModeChanged(
                            hardwareHdrAvailable
                                ? HdrMode.hardware
                                : HdrMode.strong,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _XiaomiSectionLabel('Giao diện', color: labelColor),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _XiaomiIconPill(
                          icon: Icons.dark_mode_rounded,
                          label: 'Tối',
                          selected: settings.themeMode != ThemeMode.light,
                          isDark: _isDark,
                          onTap: () => onThemeModeChanged(ThemeMode.dark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _XiaomiIconPill(
                          icon: Icons.light_mode_rounded,
                          label: 'Sáng',
                          selected: settings.themeMode == ThemeMode.light,
                          isDark: _isDark,
                          onTap: () => onThemeModeChanged(ThemeMode.light),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _XiaomiGridOption(
                icon: Icons.grid_3x3_rounded,
                label: 'Lưới 3x3',
                active: settings.showGrid,
                isDark: _isDark,
                onTap: () => onGridChanged(!settings.showGrid),
              ),
            ),
            Expanded(
              child: _XiaomiGridOption(
                icon: Icons.explore_rounded,
                label: 'Chân trời',
                active: settings.showHorizon,
                isDark: _isDark,
                onTap: () => onHorizonChanged(!settings.showHorizon),
              ),
            ),
            Expanded(
              child: _XiaomiGridOption(
                icon: Icons.filter_center_focus_rounded,
                label: 'Viền chủ thể',
                active: settings.showSubjectOutline,
                isDark: _isDark,
                onTap: () =>
                    onSubjectOutlineChanged(!settings.showSubjectOutline),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _XiaomiCameraViewport extends StatelessWidget {
  final CameraController? controller;
  final bool initializing;
  final String? errorMessage;
  final CameraUserSettings settings;
  final bool isFull;
  final double tiltDegrees;
  final Offset? focusPoint;
  final double exposureValue;
  final double exposureMin;
  final double exposureMax;
  final int countdownRemaining;
  final void Function(TapUpDetails details, Size size) onTapUp;
  final VoidCallback onRetry;
  final ValueChanged<double> onExposureChanged;

  const _XiaomiCameraViewport({
    required this.controller,
    required this.initializing,
    required this.errorMessage,
    required this.settings,
    required this.isFull,
    required this.tiltDegrees,
    required this.focusPoint,
    required this.exposureValue,
    required this.exposureMin,
    required this.exposureMax,
    required this.countdownRemaining,
    required this.onTapUp,
    required this.onRetry,
    required this.onExposureChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaSize.height;

        if (availableWidth <= 1 || availableHeight <= 1) {
          return const SizedBox.shrink();
        }

        final viewportSize = _targetSize(availableWidth, availableHeight);
        final double top;
        final double left;
        final double width;
        final double height;

        if (isFull) {
          top = 0;
          left = 0;
          width = availableWidth;
          height = availableHeight;
        } else if (settings.aspectRatio == CaptureAspectRatio.square) {
          // Centered between the top bar (80px) and the Professional/Amateur mode scroller (164px from bottom)
          top = 80 + (availableHeight - 80 - 164 - viewportSize.height) / 2;
          left = (availableWidth - viewportSize.width) / 2;
          width = viewportSize.width;
          height = viewportSize.height;
        } else {
          // ratio34 and ratio916: flush with the top bar (80px) downwards
          top = 80;
          left = (availableWidth - viewportSize.width) / 2;
          width = viewportSize.width;
          height = viewportSize.height;
        }

        return Stack(
          children: [
            Positioned(
              top: top,
              left: left,
              width: width,
              height: height,
              child: Container(
                decoration: isFull
                    ? const BoxDecoration(color: Colors.black)
                    : BoxDecoration(
                        color: Colors.black,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.8,
                        ),
                      ),
                child: LayoutBuilder(
                  builder: (context, inner) {
                    final size = Size(inner.maxWidth, inner.maxHeight);
                    final focus = focusPoint;
                    final focusX = (focus?.dx ?? 0) * size.width;
                    final focusY = (focus?.dy ?? 0) * size.height;
                    final railLeft = focus == null
                        ? 0.0
                        : (focusX > size.width - 96 ? focusX - 70 : focusX + 38);
                    final railTop = focus == null
                        ? 0.0
                        : _safeClampDouble(focusY - 54, 10.0, size.height - 118);
                    return ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          controller != null && controller!.value.isInitialized
                              ? _CameraPreviewCover(controller: controller!)
                              : _CameraFallback(
                                  errorMessage: errorMessage,
                                  initializing: initializing,
                                  onRetry: onRetry,
                                ),
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTapUp: (details) => onTapUp(details, size),
                            ),
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _XiaomiOverlayPainter(
                                showGrid: settings.showGrid,
                                showSubjectOutline: settings.showSubjectOutline,
                              ),
                            ),
                          ),
                          if (settings.showHorizon)
                            IgnorePointer(
                              child:
                                  _XiaomiHorizonIndicator(tiltDegrees: tiltDegrees),
                            ),
                          if (focus != null)
                            Positioned(
                              left: focusX - 40,
                              top: focusY - 40,
                              child: const IgnorePointer(child: _XiaomiFocusBox()),
                            ),
                          if (focus != null)
                            Positioned(
                              left:
                                  _safeClampDouble(railLeft, 4.0, size.width - 44),
                              top: railTop,
                              child: _FocusExposureRail(
                                color: const Color(0xFFFFCC00),
                                value: exposureValue,
                                min: exposureMin,
                                max: exposureMax,
                                onChanged: onExposureChanged,
                              ),
                            ),
                          if (countdownRemaining > 0)
                            IgnorePointer(
                              child: Center(
                                child: Text(
                                  '$countdownRemaining',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 88,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(color: Colors.black54, blurRadius: 16)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Size _targetSize(double maxWidth, double maxHeight) {
    if (isFull) {
      return Size(maxWidth, maxHeight);
    }

    final ratio = settings.aspectRatio.widthOverHeight;
    if (ratio == null) {
      return Size(maxWidth, maxHeight);
    }

    final availableRatio = maxWidth / maxHeight;
    if (availableRatio > ratio) {
      final height = maxHeight;
      return Size(height * ratio, height);
    }

    final width = maxWidth;
    return Size(width, width / ratio);
  }
}

class _XiaomiBottomDeck extends StatelessWidget {
  final CameraUserSettings settings;
  final bool overlay;
  final _XiaomiCameraMode activeMode;
  final bool capturing;
  final bool evDialOpen;
  final double exposureValue;
  final double exposureMin;
  final double exposureMax;
  final int countdownRemaining;
  final String? latestPath;
  final ValueChanged<double> onExposureChanged;
  final VoidCallback onExposureReset;
  final ValueChanged<_XiaomiCameraMode> onModeChanged;
  final VoidCallback onCapture;
  final VoidCallback onOpenLatestPhoto;
  final VoidCallback onSwitchCamera;

  const _XiaomiBottomDeck({
    required this.settings,
    required this.overlay,
    required this.activeMode,
    required this.capturing,
    required this.evDialOpen,
    required this.exposureValue,
    required this.exposureMin,
    required this.exposureMax,
    required this.countdownRemaining,
    required this.latestPath,
    required this.onExposureChanged,
    required this.onExposureReset,
    required this.onModeChanged,
    required this.onCapture,
    required this.onOpenLatestPhoto,
    required this.onSwitchCamera,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = settings.themeMode != ThemeMode.light || overlay;
    final deckBg = overlay
        ? Colors.transparent
        : (isDark ? Colors.black : const Color(0xFFF2F2F7));
    return Container(
      color: deckBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (overlay)
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: evDialOpen
                    ? _XiaomiExposureDial(
                        value: exposureValue,
                        min: exposureMin,
                        max: exposureMax,
                        isDark: isDark,
                        overlay: true,
                        onChanged: onExposureChanged,
                        onReset: onExposureReset,
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ),
          _XiaomiModeScroller(
            activeMode: activeMode,
            isDark: isDark,
            onModeChanged: onModeChanged,
          ),
          _XiaomiShutterControls(
            latestPath: latestPath,
            capturing: capturing,
            isDark: isDark,
            countdownRemaining: countdownRemaining,
            onCapture: onCapture,
            onOpenLatestPhoto: onOpenLatestPhoto,
            onSwitchCamera: onSwitchCamera,
          ),
        ],
      ),
    );
  }
}

class _XiaomiExposureDial extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final bool isDark;
  final bool overlay;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  const _XiaomiExposureDial({
    required this.value,
    required this.min,
    required this.max,
    required this.isDark,
    this.overlay = false,
    required this.onChanged,
    required this.onReset,
  });

  @override
  State<_XiaomiExposureDial> createState() => _XiaomiExposureDialState();
}

class _XiaomiExposureDialState extends State<_XiaomiExposureDial> {
  static const _step = 0.2;
  static const _itemWidth = 12.0;
  late final ScrollController _controller;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _controller =
        ScrollController(initialScrollOffset: _valueToOffset(widget.value));
  }

  @override
  void didUpdateWidget(covariant _XiaomiExposureDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.value != widget.value ||
            oldWidget.min != widget.min ||
            oldWidget.max != widget.max) &&
        !_dragging &&
        _controller.hasClients) {
      _controller.animateTo(
        _valueToOffset(widget.value),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _totalItems => ((widget.max - widget.min) / _step).round() + 1;

  double _valueToOffset(double value) {
    final safe = value.clamp(widget.min, widget.max).toDouble();
    return ((safe - widget.min) / _step) * _itemWidth;
  }

  double _offsetToValue(double offset) {
    final value = widget.min + (offset / _itemWidth) * _step;
    return double.parse(value.toStringAsFixed(1))
        .clamp(widget.min, widget.max)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final centerPadding =
        ((screenWidth - 156) / 2).clamp(0.0, double.maxFinite);
    final majorColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.55);
    final minorColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.22);
    final labelColor = widget.isDark ? Colors.white70 : Colors.black87;

    return Container(
      height: 80,
      color: widget.overlay
          ? Colors.black.withValues(alpha: 0.72)
          : (widget.isDark ? Colors.black : const Color(0xFFF2F2F7)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 64,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onReset,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restart_alt_rounded,
                    color: widget.isDark ? Colors.white : Colors.black,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification) {
                        setState(() => _dragging = true);
                      } else if (notification is ScrollEndNotification) {
                        setState(() => _dragging = false);
                      }
                      if (notification is ScrollUpdateNotification &&
                          notification.dragDetails != null) {
                        final value = _offsetToValue(_controller.offset);
                        if (value != widget.value) {
                          widget.onChanged(value);
                        }
                      }
                      return true;
                    },
                    child: ListView.builder(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: centerPadding),
                      itemCount: _totalItems,
                      itemBuilder: (context, index) {
                        final itemVal = widget.min + index * _step;
                        final major = (itemVal * 10).round() % 10 == 0;
                        final showLabel = (itemVal - widget.min).abs() < 0.01 ||
                            itemVal.abs() < 0.01 ||
                            (itemVal - widget.max).abs() < 0.01 ||
                            itemVal.abs() == 2.0;
                        return SizedBox(
                          width: _itemWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (showLabel)
                                Text(
                                  itemVal > 0
                                      ? '+${itemVal.toStringAsFixed(0)}'
                                      : itemVal.toStringAsFixed(0),
                                  style: TextStyle(
                                    color: labelColor,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              else
                                const SizedBox(height: 12),
                              const SizedBox(height: 6),
                              Container(
                                width: major ? 1.5 : 1.0,
                                height: major ? 20 : 12,
                                color: major ? majorColor : minorColor,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.value >= 0
                              ? '+${widget.value.toStringAsFixed(1)}'
                              : widget.value.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFFFFCC00),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                            width: 2,
                            height: 24,
                            color: const Color(0xFFFFCC00)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 52),
        ],
      ),
    );
  }
}

class _XiaomiModeScroller extends StatelessWidget {
  final _XiaomiCameraMode activeMode;
  final bool isDark;
  final ValueChanged<_XiaomiCameraMode> onModeChanged;

  const _XiaomiModeScroller({
    required this.activeMode,
    required this.isDark,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = isDark
        ? Colors.white.withValues(alpha: 0.50)
        : Colors.black.withValues(alpha: 0.50);
    return Container(
      height: 48,
      color: isDark ? Colors.black : const Color(0xFFF2F2F7),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final mode in _XiaomiCameraMode.values)
                GestureDetector(
                  onTap: () => onModeChanged(mode),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          mode.label,
                          style: TextStyle(
                            color: activeMode == mode
                                ? const Color(0xFFFFCC00)
                                : inactive,
                            fontWeight: activeMode == mode
                                ? FontWeight.w900
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: activeMode == mode ? 4 : 0,
                          height: activeMode == mode ? 4 : 0,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFCC00),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _XiaomiShutterControls extends StatelessWidget {
  final String? latestPath;
  final bool capturing;
  final bool isDark;
  final int countdownRemaining;
  final VoidCallback onCapture;
  final VoidCallback onOpenLatestPhoto;
  final VoidCallback onSwitchCamera;

  const _XiaomiShutterControls({
    required this.latestPath,
    required this.capturing,
    required this.isDark,
    required this.countdownRemaining,
    required this.onCapture,
    required this.onOpenLatestPhoto,
    required this.onSwitchCamera,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final fg = isDark ? Colors.white : Colors.black;
    final inner = countdownRemaining > 0
        ? const Color(0xFFFF453A)
        : (isDark ? Colors.white : Colors.black);
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onOpenLatestPhoto,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black26),
                ),
                child: latestPath == null
                    ? Icon(Icons.image_rounded,
                        color: fg.withValues(alpha: 0.65), size: 22)
                    : Image.file(
                        File(latestPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_rounded,
                          color: fg.withValues(alpha: 0.65),
                          size: 22,
                        ),
                      ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onCapture,
            child: AnimatedScale(
              scale: capturing ? 0.92 : 1,
              duration: const Duration(milliseconds: 120),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: fg, width: 4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: capturing ? 50 : 58,
                    height: capturing ? 50 : 58,
                    decoration: BoxDecoration(
                      color: inner,
                      borderRadius: BorderRadius.circular(capturing ? 16 : 29),
                    ),
                    child: countdownRemaining > 0
                        ? const Icon(Icons.close_rounded,
                            color: Colors.white, size: 28)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: onSwitchCamera,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cached_rounded, color: fg, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _XiaomiViewportControls extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final bool evDialOpen;
  final VoidCallback onExposureToggle;
  final ValueChanged<double> onZoomChanged;

  const _XiaomiViewportControls({
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.evDialOpen,
    required this.onExposureToggle,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    final evButton = GestureDetector(
      onTap: onExposureToggle,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: evDialOpen
              ? const Color(0xFFFFCC00).withValues(alpha: 0.95)
              : Colors.black.withValues(alpha: 0.52),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.exposure_rounded,
          color: evDialOpen ? Colors.black : Colors.white,
          size: 16,
        ),
      ),
    );

    final filterButton = GestureDetector(
      onTap: () => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Bộ lọc sẽ được nối vào pipeline AI ở bước sau.'),
          duration: Duration(milliseconds: 650),
        ),
      ),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.52),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome_rounded,
            color: Colors.white, size: 16),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        // 1:1 and 3:4 previews can be quite narrow on tall phones. In that case
        // use a compact zoom chip and hide the filter button to avoid RenderFlex
        // overflows such as width=153px from the device log.
        if (maxWidth < 190) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              evButton,
              _CompactZoomChip(
                currentZoom: currentZoom,
                minZoom: minZoom,
                maxZoom: maxZoom,
                onZoomChanged: onZoomChanged,
              ),
            ],
          );
        }

        if (maxWidth < 245) {
          return Row(
            children: [
              evButton,
              Expanded(
                child: Center(
                  child: _XiaomiZoomSelector(
                    currentZoom: currentZoom,
                    minZoom: minZoom,
                    maxZoom: maxZoom,
                    compact: true,
                    onZoomChanged: onZoomChanged,
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            evButton,
            Flexible(
              child: Center(
                child: _XiaomiZoomSelector(
                  currentZoom: currentZoom,
                  minZoom: minZoom,
                  maxZoom: maxZoom,
                  onZoomChanged: onZoomChanged,
                ),
              ),
            ),
            filterButton,
          ],
        );
      },
    );
  }
}

class _CompactZoomChip extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomChanged;

  const _CompactZoomChip({
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = <double>{minZoom, 1.0, 2.0, 5.0}
        .where((value) => value >= minZoom - 0.01 && value <= maxZoom + 0.01)
        .toList()
      ..sort();
    if (options.isEmpty) {
      options.add(1.0);
    }
    final selected = options.reduce(
      (a, b) => (a - currentZoom).abs() <= (b - currentZoom).abs() ? a : b,
    );
    final selectedIndex = options.indexOf(selected);
    final next = options[(selectedIndex + 1) % options.length];

    return GestureDetector(
      onTap: () => onZoomChanged(next),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.10), width: 0.8),
        ),
        alignment: Alignment.center,
        child: Text(
          _zoomLabel(selected),
          style: const TextStyle(
            color: Color(0xFFFFCC00),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _zoomLabel(double zoom) {
    if ((zoom - 1.0).abs() < 0.05) {
      return '1x';
    }
    if ((zoom - zoom.roundToDouble()).abs() < 0.05) {
      return '${zoom.toStringAsFixed(0)}x';
    }
    return '${zoom.toStringAsFixed(1)}x';
  }
}

class _XiaomiZoomSelector extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final bool compact;
  final ValueChanged<double> onZoomChanged;

  const _XiaomiZoomSelector({
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    this.compact = false,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = <double>{minZoom, 1.0, 2.0, 5.0}
        .where((value) => value >= minZoom - 0.01 && value <= maxZoom + 0.01)
        .toList()
      ..sort();
    if (options.isEmpty) {
      options.add(1.0);
    }
    final visibleOptions = compact && options.length > 3
        ? options
            .where((value) => value == minZoom || value == 1.0 || value == 2.0)
            .toList()
        : options;
    final selected = options.reduce(
      (a, b) => (a - currentZoom).abs() <= (b - currentZoom).abs() ? a : b,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.10), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final zoom in visibleOptions)
            GestureDetector(
              onTap: () => onZoomChanged(zoom),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected == zoom
                      ? Colors.black.withValues(alpha: 0.40)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _zoomLabel(zoom),
                  style: TextStyle(
                    color: selected == zoom
                        ? const Color(0xFFFFCC00)
                        : Colors.white.withValues(alpha: 0.70),
                    fontWeight:
                        selected == zoom ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _zoomLabel(double zoom) {
    if ((zoom - 1.0).abs() < 0.05) {
      return '1x';
    }
    if ((zoom - zoom.roundToDouble()).abs() < 0.05) {
      return zoom.toStringAsFixed(0);
    }
    return zoom.toStringAsFixed(1);
  }
}

class _XiaomiIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _XiaomiIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: color, size: 23),
      ),
    );
  }
}

class _XiaomiSectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _XiaomiSectionLabel(this.label, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _XiaomiPill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _XiaomiPill({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFFFFCC00)
        : (isDark
            ? Colors.black.withValues(alpha: 0.40)
            : Colors.white.withValues(alpha: 0.65));
    final color =
        selected ? Colors.black : (isDark ? Colors.white : Colors.black);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.10),
                ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }
}

class _XiaomiIconPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _XiaomiIconPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFFFFCC00)
        : (isDark
            ? Colors.black.withValues(alpha: 0.40)
            : Colors.white.withValues(alpha: 0.65));
    final color =
        selected ? Colors.black : (isDark ? Colors.white : Colors.black);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.10),
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _XiaomiStepper extends StatelessWidget {
  final int value;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _XiaomiStepper({
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = value > 0;
    final bg = active
        ? const Color(0xFFFFCC00)
        : (isDark
            ? Colors.black.withValues(alpha: 0.40)
            : Colors.white.withValues(alpha: 0.65));
    final color =
        active ? Colors.black : (isDark ? Colors.white54 : Colors.black45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: active
            ? null
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.10),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => onChanged(value > 1 ? value - 1 : 0),
            child: Icon(Icons.remove_rounded, size: 18, color: color),
          ),
          Text(
            active ? '${value}s' : '--',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 15),
          ),
          GestureDetector(
            onTap: () => onChanged(value == 0 ? 3 : math.min(60, value + 1)),
            child: Icon(Icons.add_rounded, size: 18, color: color),
          ),
        ],
      ),
    );
  }
}

class _XiaomiGridOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  const _XiaomiGridOption({
    required this.icon,
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFFFCC00);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: 0.18)
                  : (isDark
                      ? Colors.black.withValues(alpha: 0.40)
                      : Colors.white.withValues(alpha: 0.65)),
              shape: BoxShape.circle,
              border: Border.all(
                  color: active ? accent : Colors.transparent, width: 1.5),
            ),
            child: Icon(icon,
                color: active ? accent : (isDark ? Colors.white : Colors.black),
                size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _XiaomiOverlayPainter extends CustomPainter {
  final bool showGrid;
  final bool showSubjectOutline;

  const _XiaomiOverlayPainter({
    required this.showGrid,
    required this.showSubjectOutline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.26)
        ..strokeWidth = 0.7;
      canvas.drawLine(Offset(size.width / 3, 0),
          Offset(size.width / 3, size.height), paint);
      canvas.drawLine(Offset(size.width * 2 / 3, 0),
          Offset(size.width * 2 / 3, size.height), paint);
      canvas.drawLine(Offset(0, size.height / 3),
          Offset(size.width, size.height / 3), paint);
      canvas.drawLine(Offset(0, size.height * 2 / 3),
          Offset(size.width, size.height * 2 / 3), paint);
    }
    if (showSubjectOutline) {
      final paint = Paint()
        ..color = const Color(0xFFFFCC00).withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final subject = Rect.fromLTWH(
        size.width * 0.50,
        size.height * 0.18,
        size.width * 0.30,
        size.height * 0.58,
      );
      canvas.drawRRect(
          RRect.fromRectAndRadius(subject, const Radius.circular(36)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _XiaomiOverlayPainter oldDelegate) =>
      oldDelegate.showGrid != showGrid ||
      oldDelegate.showSubjectOutline != showSubjectOutline;
}

class _XiaomiHorizonIndicator extends StatelessWidget {
  final double tiltDegrees;

  const _XiaomiHorizonIndicator({required this.tiltDegrees});

  @override
  Widget build(BuildContext context) {
    final visualTilt = horizonDisplayRotationDegrees(tiltDegrees);
    final levelError = horizonLevelErrorDegrees(tiltDegrees).abs();
    final level = levelError < 1.5;
    final color =
        level ? const Color(0xFF00FF66) : Colors.white.withValues(alpha: 0.78);
    return Center(
      child: Transform.rotate(
        angle: visualTilt * math.pi / 180,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 1.5, color: color),
            const SizedBox(width: 4),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Container(width: 50, height: 1.5, color: color),
          ],
        ),
      ),
    );
  }
}

class _XiaomiFocusBox extends StatelessWidget {
  const _XiaomiFocusBox();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(painter: _XiaomiFocusBoxPainter()),
    );
  }
}

class _XiaomiFocusBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFCC00)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const len = 16.0;
    canvas.drawLine(Offset.zero, const Offset(len, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, len), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - len), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        final scale = math.max(
          previewRatio / screenRatio,
          screenRatio / previewRatio,
        );
        return Transform.scale(
          scale: scale,
          child: Center(child: CameraPreview(controller)),
        );
      },
    );
  }
}

class _FocusExposureRail extends StatelessWidget {
  final Color color;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _FocusExposureRail({
    required this.color,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(min, max).toDouble();
    final range = math.max(0.1, max - min);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        onChanged(
          (safeValue - (details.primaryDelta ?? 0) * range / 180)
              .clamp(min, max)
              .toDouble(),
        );
      },
      child: SizedBox(
        width: 34,
        height: 148,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 2,
              height: 112,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Positioned(
              top: ((1 - (safeValue - min) / range) * 94 + 18).clamp(
                8.0,
                118.0,
              ),
              child: Icon(Icons.wb_sunny_rounded, color: color, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraFallback extends StatelessWidget {
  final String? errorMessage;
  final bool initializing;
  final VoidCallback onRetry;

  const _CameraFallback({
    required this.errorMessage,
    required this.initializing,
    required this.onRetry,
  });

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
                            strokeWidth: 2.4,
                            color: tokens.primary,
                          ),
                        )
                      else
                        Icon(Icons.camera_alt_outlined, color: tokens.primary),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          initializing ? 'Đang mở camera...' : errorMessage!,
                          style: TextStyle(
                            color: tokens.text,
                            fontWeight: FontWeight.w700,
                          ),
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
                      onPressed: onRetry,
                    ),
                  ],
                ],
              ),
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
                strokeWidth: 2.8,
                color: tokens.primary,
              ),
            ),
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
                const Color(0xFF202A34),
                const Color(0xFF0E141A),
                i / 6,
              )!
            : Color.lerp(
                const Color(0xFFE1E2DA),
                const Color(0xFFC9CEC4),
                i / 6,
              )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height * 0.18, size.width * 0.16, h),
          const Radius.circular(12),
        ),
        building,
      );
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
        Rect.fromLTWH(
          centerX - size.width * 0.15,
          bodyTop,
          size.width * 0.28,
          size.height * 0.38,
        ),
        const Radius.circular(44),
      ),
      jacket,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, size.height * 0.33),
        width: size.width * 0.16,
        height: size.width * 0.20,
      ),
      skin,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centerX - size.width * 0.01, size.height * 0.30),
        width: size.width * 0.18,
        height: size.width * 0.15,
      ),
      math.pi,
      math.pi * 1.1,
      false,
      hair
        ..strokeWidth = 24
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _MockPortraitPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
