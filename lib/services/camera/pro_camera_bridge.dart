import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProCameraBridge {
  static const MethodChannel _channel =
      MethodChannel('x_aesthetic/pro_camera');

  const ProCameraBridge();

  Future<String> capture({
    required CameraLensDirection lensDirection,
    required String wb,
    required String focus,
    required String speed,
    required String iso,
    required double exposureOffset,
  }) async {
    if (!Platform.isAndroid) {
      throw const ProCameraUnavailableException(
          'Chế độ Chuyên nghiệp điều khiển phần cứng chỉ hoạt động trên Android trong phiên bản này.');
    }

    final tempDir = await getTemporaryDirectory();
    final id = DateTime.now().microsecondsSinceEpoch;
    final outputPath = p.join(tempDir.path, 'x_aesthetic_native_pro_$id.jpg');

    try {
      final path = await _channel.invokeMethod<String>(
        'captureProPhoto',
        {
          'lensDirection': _lensName(lensDirection),
          'outputPath': outputPath,
          'wb': wb,
          'focus': focus,
          'speed': speed,
          'iso': iso,
          'exposureOffset': exposureOffset,
        },
      );
      if (path == null || path.isEmpty) {
        throw const ProCameraUnavailableException(
            'Native Pro Capture không trả về ảnh hợp lệ.');
      }
      return path;
    } on MissingPluginException catch (error) {
      throw ProCameraUnavailableException(
          'Native Pro Camera bridge chưa được đăng ký.', error);
    } on PlatformException catch (error) {
      throw ProCameraUnavailableException(
          error.message ?? 'Lỗi camera khi chụp Pro.', error);
    }
  }

  Future<void> setHardwareFocus({
    required CameraLensDirection lensDirection,
    required String focus,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setHardwareFocus', {
        'lensDirection': _lensName(lensDirection),
        'focus': focus,
      });
    } catch (e) {
      // Silently catch platform channel errors (defensive)
    }
  }

  static String _lensName(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.front:
        return 'front';
      case CameraLensDirection.external:
        return 'external';
      case CameraLensDirection.back:
        return 'back';
    }
  }
}

class ProCameraUnavailableException implements Exception {
  final String message;
  final Object? cause;

  const ProCameraUnavailableException(this.message, [this.cause]);

  @override
  String toString() => message;
}
