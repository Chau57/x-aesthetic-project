import 'package:x_aesthetic_app/domain/entities/reference_style.dart';
import 'package:x_aesthetic_app/core/ai/aesthetic_attributes.dart';
import 'package:x_aesthetic_app/core/ai/detection_result.dart';
import 'package:x_aesthetic_app/core/camera/camera_frame.dart';
import 'package:x_aesthetic_app/core/camera/camera_pose.dart';

class PluginContext {
  final PluginPhase phase;
  final CameraFrame? frame;
  final CameraPose? cameraPose;
  final List<DetectionResult> detections;
  final AestheticAttributes? attributes;
  final ReferenceStyle? targetStyle;
  final Map<String, Object> metadata;

  const PluginContext({
    required this.phase,
    this.frame,
    this.cameraPose,
    this.detections = const [],
    this.attributes,
    this.targetStyle,
    this.metadata = const {},
  });

  bool hasDetectionLabel(String label, {double minConfidence = 0.5}) {
    return detections.any(
      (detection) =>
          detection.label == label && detection.confidence >= minConfidence,
    );
  }
}

enum PluginPhase {
  preCapture,
  postCapture,
}
