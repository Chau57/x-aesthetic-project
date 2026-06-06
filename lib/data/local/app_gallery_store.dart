import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/captured_photo.dart';

class AppGalleryStore {
  static const _folderName = 'x_aesthetic_library';
  static const _metadataFile = 'metadata.json';

  Future<Directory> _libraryDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, _folderName));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  Future<File> _metadata() async {
    final directory = await _libraryDirectory();
    return File(p.join(directory.path, _metadataFile));
  }

  Future<List<CapturedPhoto>> loadPhotos() async {
    try {
      final file = await _metadata();
      if (!file.existsSync()) {
        return <CapturedPhoto>[];
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return <CapturedPhoto>[];
      }
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => CapturedPhoto.fromJson(item as Map<String, dynamic>))
          .where((photo) => File(photo.filePath).existsSync())
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return <CapturedPhoto>[];
    }
  }

  Future<CapturedPhoto> saveCapturedImage(
    String sourcePath, {
    CaptureMetadata? metadata,
    PhotoEvaluation? evaluation,
  }) async {
    final directory = await _libraryDirectory();
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final extension =
        p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final targetPath = p.join(directory.path, 'x_aesthetic_$id$extension');
    await File(sourcePath).copy(targetPath);

    final photo = CapturedPhoto(
      id: id,
      filePath: targetPath,
      createdAt: now,
      metadata: metadata ??
          const CaptureMetadata(
              cameraLens: 'unknown',
              resolution: 'unknown',
              hdrMode: 'off',
              aspectRatio: 'ratio34',
              exposureOffset: 0,
              horizonAngle: 0,
              photoContext: 'auto'),
      evaluation: evaluation ?? PhotoEvaluation.placeholder(),
    );

    final photos = await loadPhotos();
    photos.insert(0, photo);
    await _writeMetadata(photos);
    return photo;
  }

  Future<void> updatePhoto(CapturedPhoto photo) async {
    final photos = await loadPhotos();
    final index = photos.indexWhere((item) => item.id == photo.id);
    if (index == -1) {
      return;
    }
    photos[index] = photo;
    await _writeMetadata(photos);
  }

  Future<void> deletePhoto(CapturedPhoto photo) async {
    final file = File(photo.filePath);
    if (file.existsSync()) {
      await file.delete();
    }
    final photos = await loadPhotos();
    photos.removeWhere((item) => item.id == photo.id);
    await _writeMetadata(photos);
  }

  Future<void> _writeMetadata(List<CapturedPhoto> photos) async {
    final file = await _metadata();
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
        encoder.convert(photos.map((item) => item.toJson()).toList()));
  }
}
