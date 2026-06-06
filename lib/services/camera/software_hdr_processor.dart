import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/camera_settings.dart';

class SoftwareHdrProcessor {
  const SoftwareHdrProcessor._();

  /// Applies a lightweight tone-mapping approximation.
  ///
  /// This is not hardware HDR. It is a deterministic post-processing step used
  /// for the demo phase: lift shadows, protect highlights, and add a small
  /// saturation/contrast boost so the HDR toggle has visible behavior before the
  /// native camera/AI pipeline is introduced.
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
      final sourceFile = File(sourcePath);
      final bytes = await sourceFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return sourcePath;
      }

      final image = img.Image.from(decoded);

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

          final nr =
              _toneMapChannel(r + shadowLift - highlightProtect, strength);
          final ng =
              _toneMapChannel(g + shadowLift - highlightProtect, strength);
          final nb =
              _toneMapChannel(b + shadowLift - highlightProtect, strength);

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

      final tempDir = await getTemporaryDirectory();
      final id = DateTime.now().microsecondsSinceEpoch;
      final targetPath = p.join(tempDir.path, 'x_aesthetic_hdr_$id.jpg');
      await File(targetPath).writeAsBytes(img.encodeJpg(image, quality: 94));
      return targetPath;
    } catch (_) {
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
    } catch (_) {
      return false;
    }
  }

  static int _toneMapChannel(double value, double strength) {
    final normalized = (value / 255.0).clamp(0.0, 1.0);
    final contrastAmount = 1.0 + 0.08 * strength;
    final gammaAmount = 1.0 - 0.04 * strength;
    final contrast =
        ((normalized - 0.5) * contrastAmount + 0.5).clamp(0.0, 1.0);
    final gamma = math.pow(contrast, gammaAmount).toDouble();
    return _clamp(gamma * 255.0);
  }

  static int _clamp(double value) => value.clamp(0, 255).round();
}
