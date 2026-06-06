enum PhotoContext {
  auto,
  general,
  portrait,
  landscape,
  street,
  architecture,
  food,
  product,
  macro,
  animal,
  night,
}

extension PhotoContextLabel on PhotoContext {
  String get label {
    switch (this) {
      case PhotoContext.auto:
        return 'Tự động';
      case PhotoContext.general:
        return 'Tổng quát';
      case PhotoContext.portrait:
        return 'Chân dung';
      case PhotoContext.landscape:
        return 'Phong cảnh';
      case PhotoContext.street:
        return 'Đường phố';
      case PhotoContext.architecture:
        return 'Kiến trúc';
      case PhotoContext.food:
        return 'Đồ ăn';
      case PhotoContext.product:
        return 'Sản phẩm';
      case PhotoContext.macro:
        return 'Cận cảnh';
      case PhotoContext.animal:
        return 'Động vật';
      case PhotoContext.night:
        return 'Ban đêm';
    }
  }

  String get shortLabel {
    switch (this) {
      case PhotoContext.auto:
        return 'Auto';
      case PhotoContext.general:
        return 'Tổng quát';
      case PhotoContext.portrait:
        return 'Chân dung';
      case PhotoContext.landscape:
        return 'Phong cảnh';
      case PhotoContext.street:
        return 'Đường phố';
      case PhotoContext.architecture:
        return 'Kiến trúc';
      case PhotoContext.food:
        return 'Đồ ăn';
      case PhotoContext.product:
        return 'Sản phẩm';
      case PhotoContext.macro:
        return 'Macro';
      case PhotoContext.animal:
        return 'Động vật';
      case PhotoContext.night:
        return 'Đêm';
    }
  }

  String get description {
    switch (this) {
      case PhotoContext.auto:
        return 'Để hệ thống tự suy luận bối cảnh. Giai đoạn sau sẽ thay bằng AI/ML.';
      case PhotoContext.general:
        return 'Đánh giá cân bằng theo ánh sáng, màu sắc, tương phản và bố cục cơ bản.';
      case PhotoContext.portrait:
        return 'Ưu tiên chủ thể, ánh sáng mặt, hậu cảnh và bố cục.';
      case PhotoContext.landscape:
        return 'Ưu tiên đường chân trời, dải sáng, màu sắc và cảm giác chiều sâu.';
      case PhotoContext.street:
        return 'Ưu tiên tương phản, đường dẫn, ánh sáng và cảm giác khoảnh khắc.';
      case PhotoContext.architecture:
        return 'Ưu tiên đối xứng, đường thẳng, phối cảnh và cân bằng khung hình.';
      case PhotoContext.food:
        return 'Ưu tiên màu sắc, ánh sáng mềm, nền gọn và bố cục món ăn.';
      case PhotoContext.product:
        return 'Ưu tiên chủ thể rõ, nền sạch, ánh sáng đều và tương phản.';
      case PhotoContext.macro:
        return 'Ưu tiên chủ thể cận cảnh, nền mờ, ánh sáng và màu sắc.';
      case PhotoContext.animal:
        return 'Ưu tiên chủ thể rõ, cân bằng khung hình, ánh sáng và màu sắc.';
      case PhotoContext.night:
        return 'Ưu tiên vùng sáng không cháy, chi tiết vùng tối, tương phản và chống lệch.';
    }
  }

  bool get isManual => this != PhotoContext.auto;
}

PhotoContext photoContextFromName(String? value) {
  if (value == null || value.isEmpty) {
    return PhotoContext.auto;
  }
  for (final context in PhotoContext.values) {
    if (context.name == value) {
      return context;
    }
  }
  return PhotoContext.auto;
}

class ContextAnalysis {
  final PhotoContext requestedContext;
  final PhotoContext resolvedContext;
  final double confidence;
  final List<String> evidence;

  const ContextAnalysis({
    required this.requestedContext,
    required this.resolvedContext,
    required this.confidence,
    this.evidence = const [],
  });

  bool get isManual => requestedContext != PhotoContext.auto;

  factory ContextAnalysis.manual(PhotoContext context) {
    return ContextAnalysis(
      requestedContext: context,
      resolvedContext:
          context == PhotoContext.auto ? PhotoContext.general : context,
      confidence: context == PhotoContext.auto ? 0.45 : 1.0,
      evidence: context == PhotoContext.auto
          ? const ['Chưa có AI, dùng hồ sơ tổng quát.']
          : const ['Người dùng chọn thủ công.'],
    );
  }

  factory ContextAnalysis.fromJson(Map<String, dynamic> json) {
    return ContextAnalysis(
      requestedContext:
          photoContextFromName(json['requestedContext'] as String?),
      resolvedContext:
          photoContextFromName(json['resolvedContext'] as String?) ==
                  PhotoContext.auto
              ? PhotoContext.general
              : photoContextFromName(json['resolvedContext'] as String?),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      evidence: (json['evidence'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestedContext': requestedContext.name,
      'resolvedContext': resolvedContext.name,
      'confidence': confidence,
      'evidence': evidence,
    };
  }
}
