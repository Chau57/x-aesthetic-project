import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/camera_settings.dart';

class SoftwareHdrProcessor {
  const SoftwareHdrProcessor._();

  /// Applies a lightweight tone-mapping approximation.
  ///
  /// The expensive decode/pixel-loop/encode work is done in a background isolate
  /// so the camera UI stays responsive while the capture overlay is visible.
  static Future<String> process(String sourcePath,
      {HdrMode mode = HdrMode.light}) async {
    if (mode == HdrMode.off) {
      return sourcePath;
    }

    final strength = switch (mode) {
      HdrMode.light => 1.0,
      HdrMode.strong => 1.65,
      HdrMode.hardware => 1.9,
      HdrMode.off => 0.0,
    };

    try {
      final tempDir = await getTemporaryDirectory();
      final id = DateTime.now().microsecondsSinceEpoch;
      final targetPath = p.join(tempDir.path, 'x_aesthetic_hdr_$id.jpg');
      return await compute(_processHdrInIsolate, <String, Object>{
        'sourcePath': sourcePath,
        'targetPath': targetPath,
        'strength': strength,
      });
    } catch (error, stackTrace) {
      debugPrint('Software HDR processing failed: $error\n$stackTrace');
      return sourcePath;
    }
  }

  /// Detects invalid Camera2 HDR captures that come back as almost fully black.
  ///
  /// Some Android devices report CONTROL_SCENE_MODE_HDR support but produce a
  /// black JPEG if the native 3A pipeline has not converged or if the vendor
  /// implementation is incomplete. In that case the app falls back to the
  /// normal Flutter camera capture + Software HDR Strong path.
  static Future<bool> isProbablyBlack(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return true;
      }

      final bytes = await sourceFile.readAsBytes();
      if (bytes.length < 4096) {
        return true;
      }

      return await compute(_isProbablyBlackInIsolate, bytes);
    } catch (error, stackTrace) {
      debugPrint('HDR black-frame detection failed: $error\n$stackTrace');
      return false;
    }
  }
}

double _applySCurve(double value, double contrast) {
  var norm = value / 255.0;
  if (norm < 0.5) {
    norm = 0.5 * math.pow(norm * 2.0, contrast);
  } else {
    norm = 1.0 - 0.5 * math.pow((1.0 - norm) * 2.0, contrast);
  }
  return norm * 255.0;
}

String _processHdrInIsolate(Map<String, Object> args) {
  final sourcePath = args['sourcePath']! as String;
  final targetPath = args['targetPath']! as String;
  final strength = args['strength']! as double;

  try {
    final bytes = File(sourcePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return sourcePath;
    }

    final source = img.bakeOrientation(decoded);
    final image = _resizeIfNeeded(source, maxSide: 1920);

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        var r = pixel.r.toDouble();
        var g = pixel.g.toDouble();
        var b = pixel.b.toDouble();
        final a = pixel.a.toInt();

        // Calculate luminance in 0.0 - 1.0 range
        final luma = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;

        // 1. Non-linear Shadow Lift (curves shadows up, preserves black point)
        final shadowLift = math.pow(1.0 - luma, 2.5) * 0.75 * strength;

        // 2. Highlight Compression (soft compression of bright areas)
        final highlightCompress = math.pow(luma, 2.0) * 0.28 * strength;

        // Calculate overall scaling factor
        final factor = (1.0 + shadowLift) * (1.0 - highlightCompress);

        r *= factor;
        g *= factor;
        b *= factor;

        // 3. Local S-Curve Contrast adjustment on each channel
        r = _applySCurve(r, 1.05 + 0.12 * strength);
        g = _applySCurve(g, 1.05 + 0.12 * strength);
        b = _applySCurve(b, 1.05 + 0.12 * strength);

        // 4. Smart Vibrance (boost less-saturated colors more to keep natural look)
        final maxVal = math.max(r, math.max(g, b));
        final minVal = math.min(r, math.min(g, b));
        final sat = maxVal > 0.0 ? (maxVal - minVal) / maxVal : 0.0;
        final vibranceBoost = (1.0 - sat) * 0.22 * strength;
        
        final lumaNew = (0.2126 * r + 0.7152 * g + 0.0722 * b);
        r = lumaNew + (r - lumaNew) * (1.0 + vibranceBoost);
        g = lumaNew + (g - lumaNew) * (1.0 + vibranceBoost);
        b = lumaNew + (b - lumaNew) * (1.0 + vibranceBoost);

        image.setPixelRgba(
          x,
          y,
          _clamp(r),
          _clamp(g),
          _clamp(b),
          a,
        );
      }
    }

    // Apply high-quality convolution sharpening to enhance crispness and fine details
    final sharpAmount = 0.38 * strength;
    final center = 1.0 + 4.0 * sharpAmount;
    final kernel = [
       0.0, -sharpAmount, 0.0,
      -sharpAmount, center, -sharpAmount,
       0.0, -sharpAmount, 0.0,
    ];
    final sharpenedImage = img.convolution(image, filter: kernel);

    File(targetPath).writeAsBytesSync(img.encodeJpg(sharpenedImage, quality: 95));
    return targetPath;
  } catch (error, stackTrace) {
    debugPrint('Software HDR isolate failed: $error\n$stackTrace');
    return sourcePath;
  }
}

bool _isProbablyBlackInIsolate(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      return true;
    }

    final stepX = math.max(1, decoded.width ~/ 48);
    final stepY = math.max(1, decoded.height ~/ 48);
    var count = 0;
    var sum = 0.0;
    var brightPixels = 0;

    for (var y = 0; y < decoded.height; y += stepY) {
      for (var x = 0; x < decoded.width; x += stepX) {
        final pixel = decoded.getPixel(x, y);
        final luminance =
            (0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b) / 255.0;
        sum += luminance;
        count++;
        if (luminance > 0.08) {
          brightPixels++;
        }
      }
    }

    if (count == 0) {
      return true;
    }

    final averageLuminance = sum / count;
    final brightRatio = brightPixels / count;
    return averageLuminance < 0.035 && brightRatio < 0.02;
  } catch (error, stackTrace) {
    debugPrint('HDR black-frame isolate failed: $error\n$stackTrace');
    return false;
  }
}

img.Image _resizeIfNeeded(img.Image source, {required int maxSide}) {
  final currentMaxSide = math.max(source.width, source.height);
  if (currentMaxSide <= maxSide) {
    return img.Image.from(source);
  }

  if (source.width >= source.height) {
    return img.copyResize(
      source,
      width: maxSide,
      interpolation: img.Interpolation.linear,
    );
  }

  return img.copyResize(
    source,
    height: maxSide,
    interpolation: img.Interpolation.linear,
  );
}

int _clamp(double value) => value.clamp(0, 255).round();
