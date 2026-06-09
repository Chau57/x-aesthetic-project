import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class FastVisionStats {
  final double brightness;      // Mean luminance (0.0 to 1.0)
  final double blurVariance;     // Laplacian variance of grayscale pixels (0 to 1000+)
  final double motionDifference; // Mean absolute difference between frames (0.0 to 255.0)
  final double tiltDegrees;      // Horizon tilt angle (from accelerometer)
  
  const FastVisionStats({
    required this.brightness,
    required this.blurVariance,
    required this.motionDifference,
    required this.tiltDegrees,
  });

  bool get isTooDark => brightness < 0.22;
  bool get isTooBright => brightness > 0.85;
  bool get isBlurry => blurVariance < 15.0; // Adjusted threshold for 160x120 downscaled image
  bool get isMoving => motionDifference > 35.0; // Threshold for frame change detection (adjusted to prevent false positives)
  bool get isTilted => tiltDegrees.abs() > 3.0;

  bool get hasWarnings => isTooDark || isTooBright || isBlurry || isMoving || isTilted;
  
  String? get warningMessage {
    if (isTilted) return 'Độ nghiêng: ${tiltDegrees.toStringAsFixed(1)}° (Căn thẳng máy)';
    if (isMoving) return 'Cảnh báo: Thiết bị đang rung lắc';
    if (isBlurry) return 'Cảnh báo: Ảnh bị mờ hoặc lấy nét sai';
    if (isTooDark) return 'Cảnh báo: Thiếu sáng, hãy hướng về nguồn sáng';
    if (isTooBright) return 'Cảnh báo: Ánh sáng quá gắt';
    return null;
  }
}

class FastVisionProcessor {
  const FastVisionProcessor();

  FastVisionStats analyze(img.Image image, img.Image? previousImage, double tiltDegrees) {
    // 1. Avoid resizing if the image is already downscaled
    final small = (image.width == 160 && image.height == 120)
        ? image
        : img.copyResize(image, width: 160, height: 120);
    final width = small.width;
    final height = small.height;

    // 2. Convert to grayscale array
    final grays = Uint8List(width * height);
    double luminanceSum = 0.0;
    
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = small.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        
        final gray = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
        grays[x + y * width] = gray;
        luminanceSum += gray / 255.0;
      }
    }
    final brightness = luminanceSum / (width * height);

    // 3. Compute Laplacian variance (Blur Check)
    double laplacianSum = 0.0;
    double laplacianSquaredSum = 0.0;
    int count = 0;

    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final idx = x + y * width;
        final val = grays[idx];
        final valUp = grays[x + (y - 1) * width];
        final valDown = grays[x + (y + 1) * width];
        final valLeft = grays[(x - 1) + y * width];
        final valRight = grays[(x + 1) + y * width];

        // 3x3 Laplacian operator kernel
        final lap = valUp + valDown + valLeft + valRight - 4 * val;
        laplacianSum += lap;
        laplacianSquaredSum += lap * lap;
        count++;
      }
    }

    double blurVariance = 0.0;
    if (count > 0) {
      final mean = laplacianSum / count;
      final variance = (laplacianSquaredSum / count) - mean * mean;
      blurVariance = math.max(0.0, variance);
    }

    // 4. Compute frame difference (Motion Check)
    double motionDifference = 0.0;
    if (previousImage != null) {
      final prevSmall = (previousImage.width == 160 && previousImage.height == 120)
          ? previousImage
          : img.copyResize(previousImage, width: 160, height: 120);
      double diffSum = 0.0;
      final totalPixels = width * height;
      
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final pixelCurr = small.getPixel(x, y);
          final pixelPrev = prevSmall.getPixel(x, y);
          
          final rCurr = pixelCurr.r.toInt();
          final gCurr = pixelCurr.g.toInt();
          final bCurr = pixelCurr.b.toInt();
          final grayCurr = (0.299 * rCurr + 0.587 * gCurr + 0.114 * bCurr).round();
          
          final rPrev = pixelPrev.r.toInt();
          final gPrev = pixelPrev.g.toInt();
          final bPrev = pixelPrev.b.toInt();
          final grayPrev = (0.299 * rPrev + 0.587 * gPrev + 0.114 * bPrev).round();
          
          diffSum += (grayCurr - grayPrev).abs();
        }
      }
      motionDifference = diffSum / totalPixels;
    }

    return FastVisionStats(
      brightness: brightness,
      blurVariance: blurVariance,
      motionDifference: motionDifference,
      tiltDegrees: tiltDegrees,
    );
  }
}
