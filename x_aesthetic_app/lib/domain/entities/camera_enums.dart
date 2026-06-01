import 'package:flutter/material.dart';

/// Determines how the CameraScreen behaves.
enum CameraMode {
  /// First-time capture — clean camera, no ghost overlay.
  normal,

  /// Retake with subject-placement guide overlay.
  retakeGuide,
}

/// Supported preview aspect ratios.
enum CameraAspectRatio {
  square,
  fourThree,
  sixteenNine,
  full,
}

extension CameraAspectRatioLabel on CameraAspectRatio {
  String get label {
    switch (this) {
      case CameraAspectRatio.square:
        return '1:1';
      case CameraAspectRatio.fourThree:
        return '4:3';
      case CameraAspectRatio.sixteenNine:
        return '16:9';
      case CameraAspectRatio.full:
        return 'Full';
    }
  }

  /// Returns the height/width ratio for the preview frame.
  /// Returns `null` for [full] (uses all available space).
  double? get heightRatio {
    switch (this) {
      case CameraAspectRatio.square:
        return 1.0;
      case CameraAspectRatio.fourThree:
        return 4.0 / 3.0;
      case CameraAspectRatio.sixteenNine:
        return 16.0 / 9.0;
      case CameraAspectRatio.full:
        return null;
    }
  }
}

/// Flash modes for the camera.
enum CameraFlashState {
  off,
  auto,
  on,
}

extension CameraFlashStateExt on CameraFlashState {
  IconData get icon {
    switch (this) {
      case CameraFlashState.off:
        return Icons.flash_off_rounded;
      case CameraFlashState.auto:
        return Icons.flash_auto_rounded;
      case CameraFlashState.on:
        return Icons.flash_on_rounded;
    }
  }

  Color get iconColor {
    switch (this) {
      case CameraFlashState.on:
        return Colors.amber;
      default:
        return Colors.white;
    }
  }

  /// Cycles to the next flash state: off → auto → on → off.
  CameraFlashState get next {
    switch (this) {
      case CameraFlashState.off:
        return CameraFlashState.auto;
      case CameraFlashState.auto:
        return CameraFlashState.on;
      case CameraFlashState.on:
        return CameraFlashState.off;
    }
  }
}
