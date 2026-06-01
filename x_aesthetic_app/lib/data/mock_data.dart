import 'dart:ui';
import 'package:x_aesthetic_app/domain/entities/aesthetic_result.dart';
import 'package:x_aesthetic_app/domain/entities/retake_guide.dart';

class MockData {
  static const String sampleImageUrl =
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=1000';
  static const String sampleLandscapeUrl =
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&q=80&w=1000';
  static const String sampleFoodUrl =
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&q=80&w=1000';

  static const AestheticResult initialResult = AestheticResult(
    overallScore: 7.2,
    label: "Ảnh đẹp",
    summary: "Khung hình tốt",
    factors: [
      FactorScore(
          name: "Ánh sáng", score: 7.8, status: "Tốt", needsImprovement: false),
      FactorScore(
          name: "Bố cục", score: 7.4, status: "Tốt", needsImprovement: false),
      FactorScore(
          name: "Chủ thể", score: 8.1, status: "Tốt", needsImprovement: false),
      FactorScore(
          name: "Hậu cảnh",
          score: 5.2,
          status: "Cần cải thiện",
          needsImprovement: true),
    ],
    suggestion: "Hậu cảnh hơi rối — hãy tiến gần hơn hoặc đổi góc chụp.",
  );

  static const AestheticResult retakeResult = AestheticResult(
    overallScore: 7.8,
    label: "Ảnh đẹp hơn",
    summary: "Chủ thể nổi bật hơn",
    factors: [
      FactorScore(
          name: "Ánh sáng", score: 7.9, status: "Tốt", needsImprovement: false),
      FactorScore(
          name: "Bố cục", score: 8.0, status: "Tốt", needsImprovement: false),
      FactorScore(
          name: "Chủ thể", score: 8.4, status: "Tốt", needsImprovement: false),
      FactorScore(
          name: "Hậu cảnh",
          score: 6.5,
          status: "Ổn hơn",
          needsImprovement: false),
    ],
    suggestion: "Bố cục đã cân bằng hơn. Bạn có thể lưu ảnh này vào thư viện.",
  );

  static const RetakeGuide retakeGuide = RetakeGuide(
    suggestedSubjectBounds: Rect.fromLTWH(0.18, 0.20, 0.42, 0.58),
    tip: "Đặt chủ thể vào vùng gợi ý.",
  );
}
