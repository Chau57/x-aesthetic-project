import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HardwareHdrCameraBridge {
  static const MethodChannel _channel =
      MethodChannel('x_aesthetic/hardware_hdr');

  const HardwareHdrCameraBridge();

  Future<bool> isSupported(
      {CameraLensDirection lensDirection = CameraLensDirection.back}) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final supported = await _channel.invokeMethod<bool>(
        'isHardwareHdrSupported',
        {'lensDirection': _lensName(lensDirection)},
      );
      return supported ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<String> capture(
      {CameraLensDirection lensDirection = CameraLensDirection.back}) async {
    if (!Platform.isAndroid) {
      throw const HardwareHdrUnavailableException(
          'HDR phần cứng chỉ được hỗ trợ trên Android trong MVP hiện tại.');
    }

    final tempDir = await getTemporaryDirectory();
    final id = DateTime.now().microsecondsSinceEpoch;
    final outputPath = p.join(tempDir.path, 'x_aesthetic_native_hdr_$id.jpg');

    try {
      final path = await _channel.invokeMethod<String>(
        'captureHardwareHdr',
        {
          'lensDirection': _lensName(lensDirection),
          'outputPath': outputPath,
        },
      );
      if (path == null || path.isEmpty) {
        throw const HardwareHdrUnavailableException(
            'Native HDR không trả về ảnh hợp lệ.');
      }
      return path;
    } on MissingPluginException catch (error) {
      throw HardwareHdrUnavailableException(
          'Native HDR bridge chưa được đăng ký trên platform này.', error);
    } on PlatformException catch (error) {
      throw HardwareHdrUnavailableException(
          error.message ?? 'Không chụp được ảnh HDR phần cứng.', error);
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

class HardwareHdrUnavailableException implements Exception {
  final String message;
  final Object? cause;

  const HardwareHdrUnavailableException(this.message, [this.cause]);

  @override
  String toString() => message;
}
