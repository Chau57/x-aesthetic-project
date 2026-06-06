import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'photo_context.dart';

enum HdrMode { off, light, strong, hardware }

enum CaptureAspectRatio { ratio34, ratio916, square, full }

extension CaptureAspectRatioLabel on CaptureAspectRatio {
  String get label {
    switch (this) {
      case CaptureAspectRatio.ratio34:
        return '3:4';
      case CaptureAspectRatio.ratio916:
        return '9:16';
      case CaptureAspectRatio.square:
        return '1:1';
      case CaptureAspectRatio.full:
        return 'Full';
    }
  }

  String get description {
    switch (this) {
      case CaptureAspectRatio.ratio34:
        return 'Khung dọc cân bằng, phù hợp chân dung và ảnh thường.';
      case CaptureAspectRatio.ratio916:
        return 'Khung toàn màn hình dọc, phù hợp story/reel.';
      case CaptureAspectRatio.square:
        return 'Khung vuông, phù hợp bố cục tối giản.';
      case CaptureAspectRatio.full:
        return 'Giữ nguyên toàn bộ ảnh từ camera.';
    }
  }

  double? get widthOverHeight {
    switch (this) {
      case CaptureAspectRatio.ratio34:
        return 3 / 4;
      case CaptureAspectRatio.ratio916:
        return 9 / 16;
      case CaptureAspectRatio.square:
        return 1;
      case CaptureAspectRatio.full:
        return null;
    }
  }
}

extension HdrModeLabel on HdrMode {
  String get label {
    switch (this) {
      case HdrMode.off:
        return 'Tắt';
      case HdrMode.light:
        return 'Nhẹ';
      case HdrMode.strong:
        return 'Mạnh';
      case HdrMode.hardware:
        return 'Phần cứng';
    }
  }

  String get shortLabel {
    switch (this) {
      case HdrMode.off:
        return 'Tắt';
      case HdrMode.light:
        return 'Nhẹ';
      case HdrMode.strong:
        return 'Mạnh';
      case HdrMode.hardware:
        return 'HDR+';
    }
  }

  String get description {
    switch (this) {
      case HdrMode.off:
        return 'Không xử lý hậu kỳ HDR.';
      case HdrMode.light:
        return 'Nâng vùng tối và bảo vệ vùng sáng ở mức tự nhiên.';
      case HdrMode.strong:
        return 'Tăng hiệu ứng rõ hơn cho ảnh chênh sáng mạnh.';
      case HdrMode.hardware:
        return 'Ưu tiên HDR phần cứng bằng Camera2/CameraX bridge trên Android, tự fallback nếu thiết bị không hỗ trợ.';
    }
  }
}

class CameraUserSettings {
  final HdrMode hdrMode;
  final bool showGrid;
  final bool showHorizon;
  final bool showSubjectOutline;
  final bool showSuggestionFrame;
  final ResolutionPreset resolutionPreset;
  final CaptureAspectRatio aspectRatio;
  final PhotoContext photoContext;
  final double exposureOffset;
  final ThemeMode themeMode;

  bool get hdrEnabled => hdrMode != HdrMode.off;

  const CameraUserSettings({
    this.hdrMode = HdrMode.off,
    this.showGrid = true,
    this.showHorizon = true,
    this.showSubjectOutline = true,
    this.showSuggestionFrame = true,
    this.resolutionPreset = ResolutionPreset.high,
    this.aspectRatio = CaptureAspectRatio.ratio34,
    this.photoContext = PhotoContext.auto,
    this.exposureOffset = 0,
    this.themeMode = ThemeMode.dark,
  });

  CameraUserSettings copyWith({
    HdrMode? hdrMode,
    bool? showGrid,
    bool? showHorizon,
    bool? showSubjectOutline,
    bool? showSuggestionFrame,
    ResolutionPreset? resolutionPreset,
    CaptureAspectRatio? aspectRatio,
    PhotoContext? photoContext,
    double? exposureOffset,
    ThemeMode? themeMode,
  }) {
    return CameraUserSettings(
      hdrMode: hdrMode ?? this.hdrMode,
      showGrid: showGrid ?? this.showGrid,
      showHorizon: showHorizon ?? this.showHorizon,
      showSubjectOutline: showSubjectOutline ?? this.showSubjectOutline,
      showSuggestionFrame: showSuggestionFrame ?? this.showSuggestionFrame,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      photoContext: photoContext ?? this.photoContext,
      exposureOffset: exposureOffset ?? this.exposureOffset,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

extension ResolutionPresetLabel on ResolutionPreset {
  String get label {
    switch (this) {
      case ResolutionPreset.low:
        return 'Thấp';
      case ResolutionPreset.medium:
        return 'Trung bình';
      case ResolutionPreset.high:
        return 'Cao';
      case ResolutionPreset.veryHigh:
        return 'Rất cao';
      case ResolutionPreset.ultraHigh:
        return 'Ultra';
      case ResolutionPreset.max:
        return 'Tối đa';
    }
  }
}
