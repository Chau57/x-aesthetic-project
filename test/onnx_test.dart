import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

void main() {
  test('Load ResNet18 ONNX model', () async {
    print("Initializing OrtEnv...");
    final modelPath = "models/resnet18_places365.onnx";
    expect(File(modelPath).existsSync(), isTrue);

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
      rethrow;
    }
  });
}
