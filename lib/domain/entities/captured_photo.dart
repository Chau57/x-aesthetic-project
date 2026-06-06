import 'package:camera/camera.dart';

import 'camera_settings.dart';
import 'photo_context.dart';

class CaptureMetadata {
  final String cameraLens;
  final String resolution;
  final String hdrMode;
  final String aspectRatio;
  final double exposureOffset;
  final double horizonAngle;
  final String photoContext;

  const CaptureMetadata({
    required this.cameraLens,
    required this.resolution,
    required this.hdrMode,
    required this.aspectRatio,
    required this.exposureOffset,
    required this.horizonAngle,
    required this.photoContext,
  });

  factory CaptureMetadata.fromSettings({
    required CameraLensDirection lensDirection,
    required ResolutionPreset resolutionPreset,
    required HdrMode hdrMode,
    required CaptureAspectRatio aspectRatio,
    required double exposureOffset,
    required double horizonAngle,
    required PhotoContext photoContext,
  }) {
    return CaptureMetadata(
      cameraLens: lensDirection.name,
      resolution: resolutionPreset.name,
      hdrMode: hdrMode.name,
      aspectRatio: aspectRatio.name,
      exposureOffset: exposureOffset,
      horizonAngle: horizonAngle,
      photoContext: photoContext.name,
    );
  }

  factory CaptureMetadata.fromJson(Map<String, dynamic> json) {
    return CaptureMetadata(
      cameraLens: json['cameraLens'] as String? ?? 'back',
      resolution: json['resolution'] as String? ?? 'high',
      hdrMode: json['hdrMode'] as String? ?? 'off',
      aspectRatio: json['aspectRatio'] as String? ?? 'ratio34',
      exposureOffset: (json['exposureOffset'] as num?)?.toDouble() ?? 0,
      horizonAngle: (json['horizonAngle'] as num?)?.toDouble() ?? 0,
      photoContext: json['photoContext'] as String? ?? 'auto',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cameraLens': cameraLens,
      'resolution': resolution,
      'hdrMode': hdrMode,
      'aspectRatio': aspectRatio,
      'exposureOffset': exposureOffset,
      'horizonAngle': horizonAngle,
      'photoContext': photoContext,
    };
  }

  PhotoContext get requestedPhotoContext => photoContextFromName(photoContext);
}

class PhotoEvaluation {
  final double score;
  final String verdict;
  final Map<String, double> metrics;
  final List<String> suggestions;
  final ContextAnalysis contextAnalysis;

  const PhotoEvaluation({
    required this.score,
    required this.verdict,
    required this.metrics,
    required this.suggestions,
    required this.contextAnalysis,
  });

  factory PhotoEvaluation.placeholder() {
    return const PhotoEvaluation(
      score: 0,
      verdict: 'Chưa đánh giá',
      metrics: <String, double>{},
      suggestions: <String>[],
      contextAnalysis: ContextAnalysis(
        requestedContext: PhotoContext.auto,
        resolvedContext: PhotoContext.general,
        confidence: 0,
        evidence: <String>['Chưa đánh giá.'],
      ),
    );
  }

  factory PhotoEvaluation.fromJson(Map<String, dynamic> json) {
    return PhotoEvaluation(
      score: (json['score'] as num?)?.toDouble() ?? 0,
      verdict: json['verdict'] as String? ?? 'Chưa đánh giá',
      metrics: (json['metrics'] as Map<String, dynamic>? ??
              const <String, dynamic>{})
          .map((key, value) => MapEntry(key, (value as num).toDouble())),
      suggestions: (json['suggestions'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      contextAnalysis: ContextAnalysis.fromJson(
          json['contextAnalysis'] as Map<String, dynamic>? ??
              const <String, dynamic>{}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'verdict': verdict,
      'metrics': metrics,
      'suggestions': suggestions,
      'contextAnalysis': contextAnalysis.toJson(),
    };
  }
}

class CapturedPhoto {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final CaptureMetadata metadata;
  final PhotoEvaluation evaluation;

  const CapturedPhoto({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.metadata,
    required this.evaluation,
  });

  double get score => evaluation.score;
  String get verdict => evaluation.verdict;
  Map<String, double> get metrics => evaluation.metrics;
  List<String> get suggestions => evaluation.suggestions;
  bool get hasEvaluation =>
      evaluation.score > 0 && evaluation.metrics.isNotEmpty;

  CapturedPhoto copyWith({
    String? id,
    String? filePath,
    DateTime? createdAt,
    CaptureMetadata? metadata,
    PhotoEvaluation? evaluation,
  }) {
    return CapturedPhoto(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
      evaluation: evaluation ?? this.evaluation,
    );
  }

  factory CapturedPhoto.fromJson(Map<String, dynamic> json) {
    final legacyMetrics =
        (json['metrics'] as Map<String, dynamic>? ?? const <String, dynamic>{})
            .map((key, value) => MapEntry(key, (value as num).toDouble()));
    final evaluationJson = json['evaluation'] as Map<String, dynamic>?;
    final evaluation = evaluationJson == null
        ? PhotoEvaluation(
            score: (json['score'] as num?)?.toDouble() ?? 0,
            verdict: json['verdict'] as String? ?? 'Chưa đánh giá',
            metrics: legacyMetrics,
            suggestions:
                (json['suggestions'] as List<dynamic>? ?? const <dynamic>[])
                    .map((item) => item.toString())
                    .toList(),
            contextAnalysis: ContextAnalysis.fromJson(
                json['contextAnalysis'] as Map<String, dynamic>? ??
                    const <String, dynamic>{}),
          )
        : PhotoEvaluation.fromJson(evaluationJson);

    return CapturedPhoto(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: CaptureMetadata.fromJson(
          json['metadata'] as Map<String, dynamic>? ??
              const <String, dynamic>{}),
      evaluation: evaluation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata.toJson(),
      'evaluation': evaluation.toJson(),
      // Legacy fields kept so older UI/tests or metadata readers do not break.
      'score': score,
      'verdict': verdict,
      'metrics': metrics,
      'suggestions': suggestions,
      'contextAnalysis': evaluation.contextAnalysis.toJson(),
    };
  }
}
