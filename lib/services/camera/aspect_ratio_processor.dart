import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/camera_settings.dart';

class AspectRatioProcessor {
  const AspectRatioProcessor._();

  static Future<String> crop(
      String sourcePath, CaptureAspectRatio aspectRatio) async {
    final targetRatio = aspectRatio.widthOverHeight;
    if (targetRatio == null) {
      return sourcePath;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final id = DateTime.now().microsecondsSinceEpoch;
      final targetPath =
          p.join(tempDir.path, 'x_aesthetic_${aspectRatio.name}_$id.jpg');
      return await compute(_cropInIsolate, <String, Object>{
        'sourcePath': sourcePath,
        'targetPath': targetPath,
        'targetRatio': targetRatio,
      });
    } catch (error, stackTrace) {
      debugPrint('Aspect-ratio crop failed: $error\n$stackTrace');
      return sourcePath;
    }
  }
}

String _cropInIsolate(Map<String, Object> args) {
  final sourcePath = args['sourcePath']! as String;
  final targetPath = args['targetPath']! as String;
  final targetRatio = args['targetRatio']! as double;

  try {
    final bytes = File(sourcePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return sourcePath;
    }

    final source = img.bakeOrientation(decoded);
    final currentRatio = source.width / source.height;

    var cropWidth = source.width;
    var cropHeight = source.height;

    if ((currentRatio - targetRatio).abs() < 0.01) {
      return sourcePath;
    }

    if (currentRatio > targetRatio) {
      cropWidth = math.max(1, (source.height * targetRatio).round());
    } else {
      cropHeight = math.max(1, (source.width / targetRatio).round());
    }

    final cropX = math.max(0, ((source.width - cropWidth) / 2).round());
    final cropY = math.max(0, ((source.height - cropHeight) / 2).round());
    final safeCropWidth = math.min(cropWidth, source.width - cropX).toInt();
    final safeCropHeight = math.min(cropHeight, source.height - cropY).toInt();
    final cropped = img.copyCrop(
      source,
      x: cropX,
      y: cropY,
      width: safeCropWidth,
      height: safeCropHeight,
    );

    File(targetPath).writeAsBytesSync(img.encodeJpg(cropped, quality: 92));
    return targetPath;
  } catch (error, stackTrace) {
    debugPrint('Aspect-ratio crop isolate failed: $error\n$stackTrace');
    return sourcePath;
  }
}
