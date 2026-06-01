import 'package:x_aesthetic_app/core/ai/aesthetic_attributes.dart';
import 'package:x_aesthetic_app/core/plugin/plugin_output.dart';

class AestheticResult {
  final String imageId;
  final DateTime? capturedAt;
  final double score;
  final AestheticAttributes attributes;
  final List<PluginOutput> pluginOutputs;
  final List<String> violatedRules;

  // Active UI fields
  final double overallScore;
  final String label;
  final String summary;
  final List<FactorScore> factors;
  final String suggestion;

  const AestheticResult({
    this.imageId = '',
    this.capturedAt,
    this.score = 0.0,
    this.attributes = const AestheticAttributes({}),
    this.pluginOutputs = const [],
    this.violatedRules = const [],
    // Active UI fields
    required this.overallScore,
    required this.label,
    required this.summary,
    required this.factors,
    required this.suggestion,
  });
}

class FactorScore {
  final String name;
  final double score;
  final String status;
  final bool needsImprovement;

  const FactorScore({
    required this.name,
    required this.score,
    required this.status,
    required this.needsImprovement,
  });
}
