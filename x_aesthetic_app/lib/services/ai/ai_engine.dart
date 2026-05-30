import '../../core/ai/aesthetic_attributes.dart';
import '../../core/ai/detection_result.dart';
import '../../core/camera/camera_frame.dart';

abstract interface class AiEngine {
  Future<List<DetectionResult>> detectContext(CameraFrame frame);

  Future<AestheticAttributes> predictAttributes(Object capturedImage);
}
