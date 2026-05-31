import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/camera_enums.dart';
import '../models/overlay_options.dart';
import '../models/photo_history_item.dart';
import '../models/retake_guide.dart';
import '../theme/app_colors.dart';
import '../data/mock_data.dart';
import '../widgets/camera_overlay_painter.dart';
import '../widgets/camera_control_bar.dart';
import '../widgets/ghost_outline_painter.dart';
import 'aspect_ratio_sheet.dart';
import 'overlay_guide_sheet.dart';
import 'preview_result_screen.dart';

/// A unified camera screen that supports [CameraMode.normal] and
/// [CameraMode.retakeGuide] via the [mode] parameter.
///
/// In normal mode it behaves like a clean phone camera.
/// In retakeGuide mode it additionally shows a ghost subject-placement
/// outline driven by [retakeGuide].
class CameraScreen extends StatefulWidget {
  /// Determines whether the camera is in first-capture or retake-guide mode.
  final CameraMode mode;

  /// URL of the previously captured image (used for reference in retake mode).
  final String? previousImageUrl;

  /// Guide data for the ghost overlay — required when [mode] is
  /// [CameraMode.retakeGuide].
  final RetakeGuide? retakeGuide;

  /// Photo history used to show the latest thumbnail.
  final List<PhotoHistoryItem> history;

  /// Called when the user saves a captured photo.
  final ValueChanged<PhotoHistoryItem> onSavePhoto;

  const CameraScreen({
    super.key,
    this.mode = CameraMode.normal,
    this.previousImageUrl,
    this.retakeGuide,
    required this.history,
    required this.onSavePhoto,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  // --- Camera state ---------------------------------------------------------
  CameraAspectRatio _aspectRatio = CameraAspectRatio.fourThree;
  CameraFlashState _flashState = CameraFlashState.off;
  bool _isFrontCamera = false;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  static const double _minZoom = 1.0;
  static const double _maxZoom = 4.0;

  // --- Overlay state --------------------------------------------------------
  OverlayOptions _overlayOptions = const OverlayOptions();
  bool _showGhostOverlay = true; // toggle for retake-guide ghost

  // --- Horizon stabiliser mock state ----------------------------------------
  double _tiltAngle = 0.05;
  Timer? _stabilizerTimer;

  // --- Helpers --------------------------------------------------------------
  bool get _isRetakeMode => widget.mode == CameraMode.retakeGuide;

  @override
  void initState() {
    super.initState();
    // If retake mode, enable rule-of-thirds by default
    if (_isRetakeMode) {
      _overlayOptions = const OverlayOptions(ruleOfThirds: true);
    }
    // Simulate gentle camera drift for the horizon indicator
    _stabilizerTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _overlayOptions.horizonLine) {
        setState(() {
          final double t = DateTime.now().millisecondsSinceEpoch / 1000.0;
          _tiltAngle = 0.04 * math.sin(t * 2.0) + 0.01 * math.cos(t * 5.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _stabilizerTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _toggleFlash() {
    setState(() => _flashState = _flashState.next);
    // TODO: connect to real CameraController.setFlashMode()
  }

  void _flipCamera() {
    setState(() => _isFrontCamera = !_isFrontCamera);
    // TODO: connect to real CameraController.switchCamera()
  }

  void _onZoomChipTap() {
    // Cycle 1x → 2x → 1x
    setState(() {
      _currentZoom = _currentZoom < 1.5 ? 2.0 : 1.0;
    });
    // TODO: connect to real CameraController.setZoomLevel()
  }

  void _openAspectRatioSheet() {
    AspectRatioSheet.show(
      context,
      current: _aspectRatio,
      onSelected: (ratio) => setState(() => _aspectRatio = ratio),
    );
  }

  void _openOverlayGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return OverlayGuideSheet(
              options: _overlayOptions,
              onChanged: (newOptions) {
                setModalState(() => _overlayOptions = newOptions);
                setState(() => _overlayOptions = newOptions);
              },
            );
          },
        );
      },
    );
  }

  void _capturePhoto() {
    // TODO: capture real image from CameraController
    final isRetake = _isRetakeMode;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewResultScreen(
          imageUrl: MockData.sampleImageUrl,
          result: isRetake ? MockData.retakeResult : MockData.initialResult,
          onSave: widget.onSavePhoto,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pinch-to-zoom gesture handlers
  // ---------------------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _currentZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    });
    // TODO: connect to real CameraController.setZoomLevel(_currentZoom)
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  /// Compute the preview frame height given the screen dimensions and the
  /// selected aspect ratio.
  double _previewHeight(double screenW, double screenH) {
    final ratio = _aspectRatio.heightRatio;
    if (ratio == null) return screenH; // Full
    final h = screenW * ratio;
    return h > screenH ? screenH : h;
  }

  @override
  Widget build(BuildContext context) {
    final String? lastThumb =
        widget.history.isNotEmpty ? widget.history.last.imageUrl : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenW = constraints.maxWidth;
          final double screenH = constraints.maxHeight;
          final double activeH = _previewHeight(screenW, screenH);
          final double topOffset = (screenH - activeH) / 2;

          return Stack(
            children: [
              // ── 1. Camera preview ─────────────────────────────────────
              _buildPreview(topOffset, activeH),

              // ── 2. Aspect-ratio dark masks ────────────────────────────
              if (topOffset > 0) ...[
                _buildMask(top: 0, height: topOffset),
                _buildMask(top: topOffset + activeH, bottom: 0),
              ],

              // ── 3. Top bar ────────────────────────────────────────────
              _buildTopBar(),

              // ── 4. Small chips row (above shutter) ────────────────────
              _buildChipsRow(),

              // ── 5. Bottom shutter row ─────────────────────────────────
              _buildBottomControls(lastThumb),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-builders
  // ---------------------------------------------------------------------------

  Widget _buildPreview(double topOffset, double activeH) {
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      height: activeH,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Mock camera feed
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateY(_isFrontCamera ? math.pi : 0.0)
                  ..scaleByDouble(_currentZoom, _currentZoom, 1.0, 1.0),
                child: Image.network(
                  MockData.sampleImageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // TODO: replace Image.network with real CameraPreview widget

              // Composition overlays (rule-of-thirds, horizon, suggested frame)
              CustomPaint(
                painter: CameraOverlayPainter(
                  options: _overlayOptions,
                  tiltAngle: _tiltAngle,
                ),
              ),

              // Ghost outline — retake guide mode only
              if (_isRetakeMode &&
                  _showGhostOverlay &&
                  widget.retakeGuide != null)
                CustomPaint(
                  painter: GhostOutlinePainter(
                    suggestedSubjectBounds:
                        widget.retakeGuide!.suggestedSubjectBounds,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMask({double? top, double? bottom, double? height}) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      bottom: bottom,
      height: height,
      child: IgnorePointer(
        child: Container(color: Colors.black.withValues(alpha: 0.8)),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),

              // Centre title
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isRetakeMode ? 'Chụp lại theo gợi ý' : 'X-Aesthetic',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_isRetakeMode && widget.retakeGuide != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.retakeGuide!.tip,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Right side: settings
              IconButton(
                icon: const Icon(Icons.tune_rounded,
                    color: Colors.white, size: 20),
                onPressed: _openOverlayGuide,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small functional chips placed right above the shutter row.
  Widget _buildChipsRow() {
    return Positioned(
      bottom: 120,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Aspect ratio chip
          _SmallChip(
            label: _aspectRatio.label,
            onTap: _openAspectRatioSheet,
          ),
          const SizedBox(width: 12),

          // Zoom indicator chip
          _SmallChip(
            label: '${_currentZoom.toStringAsFixed(1)}x',
            onTap: _onZoomChipTap,
          ),
          const SizedBox(width: 12),

          // Flash button
          _SmallIconButton(
            icon: _flashState.icon,
            iconColor: _flashState.iconColor,
            onTap: _toggleFlash,
          ),

          // Ghost overlay toggle (retake mode only)
          if (_isRetakeMode) ...[
            const SizedBox(width: 12),
            _SmallIconButton(
              icon: _showGhostOverlay
                  ? Icons.person_outline_rounded
                  : Icons.person_off_outlined,
              iconColor:
                  _showGhostOverlay ? AppColors.primaryGreen : Colors.white54,
              onTap: () =>
                  setState(() => _showGhostOverlay = !_showGhostOverlay),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomControls(String? lastThumb) {
    return CameraControlBar(
      onGuideTap: _openOverlayGuide,
      onShutterTap: _capturePhoto,
      bottomOffset: 36,

      // Left: gallery thumbnail
      leftButtonOverride: GestureDetector(
        onTap: () {
          // TODO: open gallery / library
        },
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.15), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: _isRetakeMode && widget.previousImageUrl != null
              ? Image.network(widget.previousImageUrl!, fit: BoxFit.cover)
              : lastThumb != null
                  ? Image.network(lastThumb, fit: BoxFit.cover)
                  : const Icon(Icons.photo_outlined,
                      color: Colors.white, size: 20),
        ),
      ),

      // Right: flip camera
      rightButtonOverride: GestureDetector(
        onTap: _flipCamera,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.15), width: 1.5),
          ),
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: _isFrontCamera ? 0.5 : 0.0,
            child: const Icon(Icons.cameraswitch_rounded,
                color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Private helper widgets
// =============================================================================

/// A small translucent capsule chip with a text label.
class _SmallChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SmallChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A small translucent circular icon button.
class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _SmallIconButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }
}
