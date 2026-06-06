import '../../domain/entities/reference_style.dart';
import '../../domain/entities/photo_context.dart';
import '../ai/aesthetic_attributes.dart';
import '../ai/detection_result.dart';
import '../camera/camera_frame.dart';
import '../camera/camera_pose.dart';

class PluginContext {
  final PluginPhase phase;
  final CameraFrame? frame;
  final CameraPose? cameraPose;
  final PhotoContext photoContext;
  final List<DetectionResult> detections;
  final AestheticAttributes? attributes;
  final ReferenceStyle? targetStyle;
  final Map<String, Object> metadata;

  const PluginContext({
    required this.phase,
    this.frame,
    this.cameraPose,
    this.photoContext = PhotoContext.general,
    this.detections = const [],
    this.attributes,
    this.targetStyle,
    this.metadata = const {},
  });

  bool matchesPhotoContext(PhotoContext context) => photoContext == context;

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
