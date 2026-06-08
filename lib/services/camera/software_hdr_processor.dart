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

    // Limit post-processing size to avoid long stalls and OOM on ultra-high
    // captures. This keeps the current MVP smooth; native/ML paths can preserve
    // full resolution later when needed.
    final source = img.bakeOrientation(decoded);
    final image = _resizeIfNeeded(source, maxSide: 1920);

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final a = pixel.a.toInt();

        final luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
        final shadowLift = (1.0 - luminance) * 18.0 * strength;
        final highlightProtect =
            luminance > 0.72 ? (luminance - 0.72) * 42.0 * strength : 0.0;

        final nr = _toneMapChannel(r + shadowLift - highlightProtect, strength);
        final ng = _toneMapChannel(g + shadowLift - highlightProtect, strength);
        final nb = _toneMapChannel(b + shadowLift - highlightProtect, strength);

        final avg = (nr + ng + nb) / 3.0;
        final saturationBoost = 1.0 + 0.06 * strength;
        image.setPixelRgba(
          x,
          y,
          _clamp(avg + (nr - avg) * saturationBoost),
          _clamp(avg + (ng - avg) * saturationBoost),
          _clamp(avg + (nb - avg) * saturationBoost),
          a,
        );
      }
    }

    File(targetPath).writeAsBytesSync(img.encodeJpg(image, quality: 92));
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

int _toneMapChannel(double value, double strength) {
  final normalized = (value / 255.0).clamp(0.0, 1.0);
  final contrastAmount = 1.0 + 0.08 * strength;
  final gammaAmount = 1.0 - 0.04 * strength;
  final contrast = ((normalized - 0.5) * contrastAmount + 0.5).clamp(0.0, 1.0);
  final gamma = math.pow(contrast, gammaAmount).toDouble();
  return _clamp(gamma * 255.0);
}

int _clamp(double value) => value.clamp(0, 255).round();
