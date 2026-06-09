import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:x_aesthetic_app/domain/entities/camera_settings.dart';
import 'package:x_aesthetic_app/services/camera/aspect_ratio_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    // Stub path provider for testing
    final systemTemp = Directory.systemTemp.createTempSync();
    tempDir = systemTemp;

    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getTemporaryDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  String createTestImage(int width, int height, String name) {
    final image = img.Image(width: width, height: height);
    // Fill with a color
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    final jpegBytes = img.encodeJpg(image);
    final filePath = p.join(tempDir.path, name);
    File(filePath).writeAsBytesSync(jpegBytes);
    return filePath;
  }

  group('AspectRatioProcessor', () {
    test('Portrait source image (300x400) - AspectRatio 3:4 (no crop)', () async {
      final source = createTestImage(300, 400, 'portrait_3_4.jpg');
      final resultPath = await AspectRatioProcessor.crop(source, CaptureAspectRatio.ratio34);
      
      // Since source is already 3:4 (0.75), it should return source directly without cropping
      expect(resultPath, equals(source));
    });

    test('Portrait source image (300x400) - AspectRatio 1:1 (crop to 300x300)', () async {
      final source = createTestImage(300, 400, 'portrait_1_1.jpg');
      final resultPath = await AspectRatioProcessor.crop(source, CaptureAspectRatio.square);
      
      final resultBytes = File(resultPath).readAsBytesSync();
      final resultImg = img.decodeImage(resultBytes)!;
      
      expect(resultImg.width, equals(300));
      expect(resultImg.height, equals(300));
    });

    test('Portrait source image (300x400) - AspectRatio 9:16 (crop width to 225x400)', () async {
      final source = createTestImage(300, 400, 'portrait_9_16.jpg');
      final resultPath = await AspectRatioProcessor.crop(source, CaptureAspectRatio.ratio916);
      
      final resultBytes = File(resultPath).readAsBytesSync();
      final resultImg = img.decodeImage(resultBytes)!;
      
      expect(resultImg.width, equals(225));
      expect(resultImg.height, equals(400));
    });

    test('Landscape source image (400x300) - AspectRatio 3:4 (adapts to 4:3, no crop)', () async {
      final source = createTestImage(400, 300, 'landscape_4_3.jpg');
      final resultPath = await AspectRatioProcessor.crop(source, CaptureAspectRatio.ratio34);
      
      // Landscape 4:3 matches adapted target ratio of 4:3, should not crop
      expect(resultPath, equals(source));
    });

    test('Landscape source image (400x300) - AspectRatio 9:16 (adapts to 16:9, crop height to 400x225)', () async {
      final source = createTestImage(400, 300, 'landscape_16_9.jpg');
      final resultPath = await AspectRatioProcessor.crop(source, CaptureAspectRatio.ratio916);
      
      final resultBytes = File(resultPath).readAsBytesSync();
      final resultImg = img.decodeImage(resultBytes)!;
      
      expect(resultImg.width, equals(400));
      expect(resultImg.height, equals(225));
    });

    test('Two-step crop (Portrait sensor 3:4, Preview 16:9, Viewport 1:1) -> Crops to 1:1 composition matched to preview field of view', () async {
      // Source image: 300x400 (3:4, typical portrait sensor)
      final source = createTestImage(300, 400, 'sensor_3_4.jpg');
      
      // Preview size: 1920x1080 (16:9, standard phone screen viewport format)
      // View ratio: 1.0 (Square viewport layout 1:1)
      final resultPath = await AspectRatioProcessor.crop(
        source,
        CaptureAspectRatio.square,
        previewSize: const Size(1920, 1080),
        viewRatio: 1.0,
      );
      
      final resultBytes = File(resultPath).readAsBytesSync();
      final resultImg = img.decodeImage(resultBytes)!;
      
      // 1. Crop 300x400 to preview ratio 1080/1920 (0.5625) -> crops height first, giving 225x400
      // 2. Crop 225x400 to adapted target ratio 1.0 -> crops height to match width, giving 225x225.
      expect(resultImg.width, equals(225));
      expect(resultImg.height, equals(225));
    });
  });
}
