import 'dart:io';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

void main() async {
  print("Initializing OrtEnv...");
  // OrtEnv.instance is a singleton. It initializes the environment.
  final modelPath = "models/resnet18_places365.onnx";
  if (!File(modelPath).existsSync()) {
    print("Error: Model file does not exist at $modelPath");
    return;
  }

  print("Loading session options...");
  final sessionOptions = OrtSessionOptions();
  
  print("Creating OrtSession from file...");
  try {
    final session = OrtSession.fromFile(File(modelPath), sessionOptions);
    print("OrtSession successfully initialized!");
    print("Inputs: ${session.inputNames}");
    print("Outputs: ${session.outputNames}");
    await session.release();
  } catch (e) {
    print("Error loading OrtSession: $e");
  }
}
