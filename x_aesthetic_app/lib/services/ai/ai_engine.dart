import 'package:x_aesthetic_app/core/ai/aesthetic_attributes.dart';
import 'package:x_aesthetic_app/core/ai/detection_result.dart';
import 'package:x_aesthetic_app/core/camera/camera_frame.dart';

abstract interface class AiEngine {
  Future<List<DetectionResult>> detectContext(CameraFrame frame);

  Future<AestheticAttributes> predictAttributes(Object capturedImage);
}
