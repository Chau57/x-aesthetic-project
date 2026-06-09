import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/photo_context.dart';
import '../ai/local_ai_engine.dart';

class RuleBasedPhotoEvaluator {
  const RuleBasedPhotoEvaluator();

  Future<PhotoEvaluation> evaluate(String imagePath,
      {CaptureMetadata? metadata}) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return _fallback(metadata);
      }
      final image =
          img.copyResize(decoded, width: math.min(decoded.width, 480).toInt());
      final stats = _ImageStats.fromImage(image);
      final context = _resolveContext(stats, metadata);

      final base = _BaseScores(
        light: _lightingScore(stats),
        contrast: _contrastScore(stats),
        color: _colorScore(stats),
        balance: _balanceScore(metadata?.horizonAngle ?? 0),
        hdr: _dynamicRangeScore(stats, metadata?.hdrMode ?? 'off'),
      );

      final metrics =
          _contextMetrics(context.resolvedContext, base, stats, metadata);
      final score = _contextWeightedScore(context.resolvedContext, metrics);

      List<String> suggestions = [];
      try {
        await LocalAiEngine.instance.init();
        final category =
            await LocalAiEngine.instance.classifyImagePath(imagePath);
        final aiAdvice = await LocalAiEngine.instance.generateAdvice(
          category,
          stats.meanLuminance,
          stats.luminanceStdDev *
              1000.0, // Scale variance to typical 0-1000 range
        );
        if (aiAdvice.isNotEmpty) {
          suggestions.add(aiAdvice);
        }
      } catch (e) {
        print("Local AI advice failed in evaluator: $e");
      }

      return PhotoEvaluation(
        score: score,
        verdict: _verdict(score),
        metrics: metrics,
        suggestions: suggestions,
        contextAnalysis: context,
      );
    } catch (_) {
      return _fallback(metadata);
    }
  }

  PhotoEvaluation _fallback(CaptureMetadata? metadata) {
    final requested = metadata?.requestedPhotoContext ?? PhotoContext.auto;
    final resolved =
        requested == PhotoContext.auto ? PhotoContext.general : requested;
    final context = ContextAnalysis(
      requestedContext: requested,
      resolvedContext: resolved,
      confidence: requested == PhotoContext.auto ? 0.35 : 1.0,
      evidence: requested == PhotoContext.auto
          ? const ['Không đọc được ảnh, dùng hồ sơ tổng quát.']
          : const ['Người dùng chọn thủ công.'],
    );
    final balance = _balanceScore(metadata?.horizonAngle ?? 0);
    final base = _BaseScores(
      light: 7.0,
      contrast: 6.8,
      color: 7.0,
      balance: balance,
      hdr: metadata?.hdrMode == 'off' ? 6.5 : 7.2,
    );
    final metrics = _contextMetrics(resolved, base, null, metadata);
    final score = _contextWeightedScore(resolved, metrics);
    return PhotoEvaluation(
      score: score,
      verdict: _verdict(score),
      metrics: metrics,
      suggestions: const [],
      contextAnalysis: context,
    );
  }

  ContextAnalysis _resolveContext(
      _ImageStats stats, CaptureMetadata? metadata) {
    final requested = metadata?.requestedPhotoContext ?? PhotoContext.auto;
    if (requested != PhotoContext.auto) {
      return ContextAnalysis(
        requestedContext: requested,
        resolvedContext: requested,
        confidence: 1.0,
        evidence: const ['Người dùng chọn thủ công trong Cài đặt camera.'],
      );
    }

    final evidence = <String>[];
    var resolved = PhotoContext.general;
    var confidence = 0.42;

    if (stats.meanLuminance < 0.30 && stats.highlightRatio > 0.015) {
      resolved = PhotoContext.night;
      confidence = 0.62;
      evidence.add('Ảnh tối, có vùng highlight mạnh.');
    } else if (stats.meanSaturation > 0.48 && stats.meanLuminance > 0.42) {
      resolved = PhotoContext.food;
      confidence = 0.54;
      evidence.add('Màu sắc nổi bật và ánh sáng tương đối rõ.');
    } else if ((metadata?.aspectRatio ?? '') == 'ratio916' &&
        ((metadata?.horizonAngle ?? 0).abs()) < 3.0) {
      resolved = PhotoContext.landscape;
      confidence = 0.50;
      evidence.add('Khung dọc và đường chân trời tương đối ổn.');
    } else if (stats.luminanceStdDev > 0.20) {
      resolved = PhotoContext.street;
      confidence = 0.48;
      evidence.add('Tương phản cao, phù hợp ảnh đường phố/tổng quát.');
    } else {
      evidence.add('Chưa có AI nhận diện chủ thể, dùng hồ sơ tổng quát.');
    }

    return ContextAnalysis(
      requestedContext: PhotoContext.auto,
      resolvedContext: resolved,
      confidence: confidence,
      evidence: evidence,
    );
  }

  Map<String, double> _contextMetrics(PhotoContext context, _BaseScores base,
      _ImageStats? stats, CaptureMetadata? metadata) {
    final clarity =
        _clampScore(base.contrast * 0.42 + base.light * 0.38 + base.hdr * 0.20);
    final background = _clampScore(base.contrast * 0.25 +
        base.color * 0.25 +
        base.light * 0.25 +
        base.hdr * 0.25);
    final composition = _clampScore(
        base.balance * 0.55 + base.contrast * 0.25 + base.light * 0.20);
    final depth =
        _clampScore(base.contrast * 0.50 + base.color * 0.25 + base.hdr * 0.25);
    final straightLines =
        _clampScore(base.balance * 0.72 + base.contrast * 0.28);
    final cleanBackground = _clampScore(background -
        ((stats?.shadowRatio ?? 0) + (stats?.highlightRatio ?? 0)) * 2.0);
    final dynamicRange = base.hdr;

    switch (context) {
      case PhotoContext.portrait:
        return {
          'Chủ thể': clarity,
          'Ánh sáng': base.light,
          'Hậu cảnh': cleanBackground,
          'Bố cục': composition,
        };
      case PhotoContext.landscape:
        return {
          'Đường chân trời': base.balance,
          'Dải sáng': dynamicRange,
          'Màu sắc': base.color,
          'Chiều sâu': depth,
        };
      case PhotoContext.street:
        return {
          'Khoảnh khắc': clarity,
          'Đường dẫn': composition,
          'Tương phản': base.contrast,
          'Ánh sáng': base.light,
        };
      case PhotoContext.architecture:
        return {
          'Đối xứng': composition,
          'Phối cảnh': straightLines,
          'Đường thẳng': base.balance,
          'Ánh sáng': base.light,
        };
      case PhotoContext.food:
        return {
          'Màu sắc': base.color,
          'Ánh sáng': base.light,
          'Nền': cleanBackground,
          'Bố cục': composition,
        };
      case PhotoContext.product:
        return {
          'Chủ thể': clarity,
          'Nền': cleanBackground,
          'Ánh sáng': base.light,
          'Tương phản': base.contrast,
        };
      case PhotoContext.macro:
        return {
          'Chủ thể': clarity,
          'Nền mờ': background,
          'Ánh sáng': base.light,
          'Màu sắc': base.color,
        };
      case PhotoContext.animal:
        return {
          'Chủ thể': clarity,
          'Cân bằng': base.balance,
          'Ánh sáng': base.light,
          'Màu sắc': base.color,
        };
      case PhotoContext.night:
        return {
          'Vùng sáng':
              _clampScore(10.0 - (stats?.highlightRatio ?? 0.05) * 22.0),
          'Chi tiết tối': _clampScore(10.0 -
              (stats?.shadowRatio ?? 0.12) * 16.0 +
              (metadata?.hdrMode == 'off' ? 0 : 0.5)),
          'Tương phản': base.contrast,
          'Cân bằng': base.balance,
        };
      case PhotoContext.auto:
      case PhotoContext.general:
        return {
          'Ánh sáng': base.light,
          'Tương phản': base.contrast,
          'Màu sắc': base.color,
          'Cân bằng': base.balance,
          'HDR': base.hdr,
        };
    }
  }

  double _contextWeightedScore(
      PhotoContext context, Map<String, double> metrics) {
    if (metrics.isEmpty) {
      return 0;
    }
    final values = metrics.values.toList();
    return _clampScore(values.reduce((a, b) => a + b) / values.length);
  }

  double _lightingScore(_ImageStats stats) {
    final target = 0.52;
    final exposurePenalty = (stats.meanLuminance - target).abs() * 12.0;
    final clippingPenalty = (stats.shadowRatio + stats.highlightRatio) * 3.0;
    return _clampScore(10.0 - exposurePenalty - clippingPenalty);
  }

  double _contrastScore(_ImageStats stats) {
    final score = 4.8 + stats.luminanceStdDev * 18.0;
    return _clampScore(score);
  }

  double _colorScore(_ImageStats stats) {
    final target = 0.34;
    final penalty = (stats.meanSaturation - target).abs() * 8.0;
    return _clampScore(8.2 - penalty);
  }

  double _balanceScore(double angle) {
    return _clampScore(10.0 - angle.abs() * 1.35);
  }

  double _dynamicRangeScore(_ImageStats stats, String hdrMode) {
    final clipping = stats.shadowRatio + stats.highlightRatio;
    final base = 8.2 - clipping * 6.0;
    final bonus = hdrMode == 'off'
        ? 0.0
        : hdrMode == 'hardware'
            ? 0.6
            : 0.3;
    return _clampScore(base + bonus);
  }

  String _verdict(double score) {
    if (score >= 8.2) {
      return 'Rất tốt';
    }
    if (score >= 7.2) {
      return 'Ảnh đẹp';
    }
    if (score >= 6.2) {
      return 'Khá ổn';
    }
    return 'Cần cải thiện';
  }

  double _clampScore(double value) => value.clamp(0.0, 10.0).toDouble();
}

class _BaseScores {
  final double light;
  final double contrast;
  final double color;
  final double balance;
  final double hdr;

  const _BaseScores({
    required this.light,
    required this.contrast,
    required this.color,
    required this.balance,
    required this.hdr,
  });
}

class _ImageStats {
  final double meanLuminance;
  final double luminanceStdDev;
  final double meanSaturation;
  final double shadowRatio;
  final double highlightRatio;

  const _ImageStats({
    required this.meanLuminance,
    required this.luminanceStdDev,
    required this.meanSaturation,
    required this.shadowRatio,
    required this.highlightRatio,
  });

  factory _ImageStats.fromImage(img.Image image) {
    var luminanceSum = 0.0;
    var luminanceSquaredSum = 0.0;
    var saturationSum = 0.0;
    var shadows = 0;
    var highlights = 0;
    var count = 0;

    final stepX = math.max(1, image.width ~/ 420);
    final stepY = math.max(1, image.height ~/ 420);

    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        final pixel = image.getPixel(x, y);
        final r = (pixel.r / 255.0).toDouble();
        final g = (pixel.g / 255.0).toDouble();
        final b = (pixel.b / 255.0).toDouble();
        final luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        final maxChannel = math.max(r, math.max(g, b));
        final minChannel = math.min(r, math.min(g, b));
        final saturation =
            maxChannel == 0 ? 0.0 : (maxChannel - minChannel) / maxChannel;

        luminanceSum += luminance;
        luminanceSquaredSum += luminance * luminance;
        saturationSum += saturation;
        if (luminance < 0.08) {
          shadows++;
        }
        if (luminance > 0.92) {
          highlights++;
        }
        count++;
      }
    }

    if (count == 0) {
      return const _ImageStats(
        meanLuminance: 0.5,
        luminanceStdDev: 0.15,
        meanSaturation: 0.3,
        shadowRatio: 0,
        highlightRatio: 0,
      );
    }

    final mean = luminanceSum / count;
    final variance = (luminanceSquaredSum / count) - mean * mean;
    return _ImageStats(
      meanLuminance: mean,
      luminanceStdDev: math.sqrt(math.max(0, variance)),
      meanSaturation: saturationSum / count,
      shadowRatio: shadows / count,
      highlightRatio: highlights / count,
    );
  }
}
