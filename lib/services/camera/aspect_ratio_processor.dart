import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/camera_settings.dart';

class AspectRatioProcessor {
  const AspectRatioProcessor._();

  static Future<String> crop(
    String sourcePath,
    CaptureAspectRatio aspectRatio, {
    Size? previewSize,
    double? viewRatio,
  }) async {
    final targetRatio = viewRatio ?? aspectRatio.widthOverHeight;
    if (targetRatio == null && previewSize == null) {
      return sourcePath;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final id = DateTime.now().microsecondsSinceEpoch;
      final targetPath =
          p.join(tempDir.path, 'x_aesthetic_${aspectRatio.name}_$id.jpg');

      final Map<String, Object> args = {
        'sourcePath': sourcePath,
        'targetPath': targetPath,
      };
      if (targetRatio != null) {
        args['targetRatio'] = targetRatio;
      }
      if (previewSize != null) {
        args['previewWidth'] = previewSize.width;
        args['previewHeight'] = previewSize.height;
      }

      return await compute(_cropInIsolate, args);
    } catch (error, stackTrace) {
      debugPrint('Aspect-ratio crop failed: $error\n$stackTrace');
      return sourcePath;
    }
  }
}

String _cropInIsolate(Map<String, Object> args) {
  final sourcePath = args['sourcePath']! as String;
  final targetPath = args['targetPath']! as String;
  final targetRatio = args['targetRatio'] as double?;
  final previewWidth = args['previewWidth'] as double?;
  final previewHeight = args['previewHeight'] as double?;

  try {
    final bytes = File(sourcePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return sourcePath;
    }

    final source = img.bakeOrientation(decoded);
    final isLandscape = source.width >= source.height;

    var workingImg = source;

    // 1. Crop to match the aspect ratio of the preview stream first (if previewSize is available)
    if (previewWidth != null && previewHeight != null) {
      final double prevWidth;
      final double prevHeight;
      if (isLandscape) {
        prevWidth = math.max(previewWidth, previewHeight);
        prevHeight = math.min(previewWidth, previewHeight);
      } else {
        prevWidth = math.min(previewWidth, previewHeight);
        prevHeight = math.max(previewWidth, previewHeight);
      }
      final prevRatio = prevWidth / prevHeight;
      final currentRatio = workingImg.width / workingImg.height;

      if ((currentRatio - prevRatio).abs() >= 0.01) {
        var cropWidth = workingImg.width;
        var cropHeight = workingImg.height;
        if (currentRatio > prevRatio) {
          cropWidth = math.max(1, (workingImg.height * prevRatio).round());
        } else {
          cropHeight = math.max(1, (workingImg.width / prevRatio).round());
        }
        final cropX = math.max(0, ((workingImg.width - cropWidth) / 2).round());
        final cropY = math.max(0, ((workingImg.height - cropHeight) / 2).round());
        final safeCropWidth = math.min(cropWidth, workingImg.width - cropX).toInt();
        final safeCropHeight = math.min(cropHeight, workingImg.height - cropY).toInt();
        workingImg = img.copyCrop(
          workingImg,
          x: cropX,
          y: cropY,
          width: safeCropWidth,
          height: safeCropHeight,
        );
      }
    }

    // 2. Crop to match the UI viewport aspect ratio (what the user sees in the screen viewfinder)
    if (targetRatio != null) {
      final double adaptedTargetRatio;
      if (isLandscape && targetRatio < 1.0) {
        adaptedTargetRatio = 1.0 / targetRatio;
      } else {
        adaptedTargetRatio = targetRatio;
      }

      final currentRatio = workingImg.width / workingImg.height;
      if ((currentRatio - adaptedTargetRatio).abs() >= 0.01) {
        var cropWidth = workingImg.width;
        var cropHeight = workingImg.height;
        if (currentRatio > adaptedTargetRatio) {
          cropWidth = math.max(1, (workingImg.height * adaptedTargetRatio).round());
        } else {
          cropHeight = math.max(1, (workingImg.width / adaptedTargetRatio).round());
        }
        final cropX = math.max(0, ((workingImg.width - cropWidth) / 2).round());
        final cropY = math.max(0, ((workingImg.height - cropHeight) / 2).round());
        final safeCropWidth = math.min(cropWidth, workingImg.width - cropX).toInt();
        final safeCropHeight = math.min(cropHeight, workingImg.height - cropY).toInt();
        workingImg = img.copyCrop(
          workingImg,
          x: cropX,
          y: cropY,
          width: safeCropWidth,
          height: safeCropHeight,
        );
      }
    }

    if (workingImg.width == source.width && workingImg.height == source.height) {
      return sourcePath;
    }

    File(targetPath).writeAsBytesSync(img.encodeJpg(workingImg, quality: 92));
    return targetPath;
  } catch (error, stackTrace) {
    debugPrint('Aspect-ratio crop isolate failed: $error\n$stackTrace');
    return sourcePath;
  }
}
