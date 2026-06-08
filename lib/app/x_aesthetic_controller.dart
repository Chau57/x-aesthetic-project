import 'package:flutter/material.dart';

import '../data/local/app_gallery_store.dart';
import '../domain/entities/camera_settings.dart';
import '../domain/entities/captured_photo.dart';

class XAestheticController extends ChangeNotifier {
  final AppGalleryStore _galleryStore;

  XAestheticController({AppGalleryStore? galleryStore})
      : _galleryStore = galleryStore ?? AppGalleryStore();

  CameraUserSettings _settings = const CameraUserSettings();
  List<CapturedPhoto> _photos = <CapturedPhoto>[];
  String? _currentCapturePath;
  CaptureMetadata? _pendingCaptureMetadata;
  bool _isLoadingLibrary = false;
  bool _disposed = false;

  CameraUserSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  List<CapturedPhoto> get photos => List.unmodifiable(_photos);
  String? get currentCapturePath => _currentCapturePath;
  CaptureMetadata? get pendingCaptureMetadata => _pendingCaptureMetadata;
  bool get isLoadingLibrary => _isLoadingLibrary;
  CapturedPhoto? get latestPhoto => _photos.isEmpty ? null : _photos.first;

  Future<void> initialize() async {
    await refreshLibrary();
  }

  Future<void> refreshLibrary() async {
    _isLoadingLibrary = true;
    _notifyIfAlive();
    try {
      final photos = await _galleryStore.loadPhotos();
      if (_disposed) {
        return;
      }
      _photos = photos;
    } finally {
      if (!_disposed) {
        _isLoadingLibrary = false;
        _notifyIfAlive();
      }
    }
  }

  void setCurrentCapture(String? path, {CaptureMetadata? metadata}) {
    if (_disposed) {
      return;
    }
    _currentCapturePath = path;
    _pendingCaptureMetadata = metadata;
    _notifyIfAlive();
  }

  CapturedPhoto? findPhotoByPath(String path) {
    for (final photo in _photos) {
      if (photo.filePath == path) {
        return photo;
      }
    }
    return null;
  }

  Future<CapturedPhoto?> saveCurrentCaptureToLibrary(
      {PhotoEvaluation? evaluation}) async {
    final path = _currentCapturePath;
    if (path == null) {
      return null;
    }
    final photo = await _galleryStore.saveCapturedImage(
      path,
      metadata: _pendingCaptureMetadata,
      evaluation: evaluation,
    );
    if (_disposed) {
      return photo;
    }
    _photos = [photo, ..._photos.where((item) => item.id != photo.id)];
    _pendingCaptureMetadata = null;
    _notifyIfAlive();
    return photo;
  }

  Future<void> updatePhotoEvaluation(
      CapturedPhoto photo, PhotoEvaluation evaluation) async {
    final updated = photo.copyWith(evaluation: evaluation);
    await _galleryStore.updatePhoto(updated);
    if (_disposed) {
      return;
    }
    _photos = _photos
        .map((item) => item.id == updated.id ? updated : item)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _notifyIfAlive();
  }

  Future<void> deletePhoto(CapturedPhoto photo) async {
    await _galleryStore.deletePhoto(photo);
    if (_disposed) {
      return;
    }
    _photos = _photos.where((item) => item.id != photo.id).toList();
    _notifyIfAlive();
  }

  void updateSettings(CameraUserSettings settings) {
    if (_disposed) {
      return;
    }
    _settings = settings;
    _notifyIfAlive();
  }

  void updateThemeMode(ThemeMode mode) {
    if (_disposed) {
      return;
    }
    _settings = _settings.copyWith(themeMode: mode);
    _notifyIfAlive();
  }

  void _notifyIfAlive() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class XAestheticScope extends InheritedNotifier<XAestheticController> {
  const XAestheticScope({
    required XAestheticController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static XAestheticController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<XAestheticScope>();
    assert(scope != null, 'XAestheticScope was not found in context.');
    return scope!.notifier!;
  }
}
