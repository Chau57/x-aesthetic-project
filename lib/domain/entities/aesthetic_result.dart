import '../../core/ai/aesthetic_attributes.dart';
import '../../core/plugin/plugin_output.dart';

class AestheticResult {
  final String imageId;
  final DateTime capturedAt;
  final double score;
  final AestheticAttributes attributes;
  final List<PluginOutput> pluginOutputs;
  final List<String> violatedRules;

  const AestheticResult({
    required this.imageId,
    required this.capturedAt,
    required this.score,
    required this.attributes,
    this.pluginOutputs = const [],
    this.violatedRules = const [],
  });
}
