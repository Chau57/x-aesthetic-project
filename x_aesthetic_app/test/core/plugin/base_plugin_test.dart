import 'package:flutter_test/flutter_test.dart';
import 'package:x_aesthetic_app/core/ai/detection_result.dart';
import 'package:x_aesthetic_app/core/plugin/base_plugin.dart';
import 'package:x_aesthetic_app/core/plugin/guidance_message.dart';
import 'package:x_aesthetic_app/core/plugin/overlay_instruction.dart';
import 'package:x_aesthetic_app/core/plugin/plugin_context.dart';
import 'package:x_aesthetic_app/core/plugin/plugin_manager.dart';
import 'package:x_aesthetic_app/core/plugin/plugin_output.dart';
import 'package:x_aesthetic_app/core/plugin/plugin_registry.dart';

void main() {
  test('PluginManager activates registered plugin by context label', () async {
    final registry = PluginRegistry()..register(_RuleOfThirdsPlugin());
    final manager = PluginManager(registry);

    final outputs = await manager.evaluate(
      const PluginContext(
        phase: PluginPhase.preCapture,
        detections: [
          DetectionResult(
            label: 'person',
            confidence: 0.92,
            x: 0.2,
            y: 0.1,
            width: 0.4,
            height: 0.8,
          ),
        ],
      ),
    );

    expect(outputs, hasLength(1));
    expect(outputs.single.pluginId, 'rule_of_thirds');
    expect(outputs.single.overlays.single.type, OverlayType.ruleOfThirdsGrid);
  });
}

class _RuleOfThirdsPlugin implements AestheticPlugin {
  @override
  String get id => 'rule_of_thirds';

  @override
  String get name => 'Rule of Thirds';

  @override
  String get description => 'Displays a rule-of-thirds composition grid.';

  @override
  PluginStatus get status => PluginStatus.active;

  @override
  Set<PluginPhase> get supportedPhases => {PluginPhase.preCapture};

  @override
  Set<String> get supportedContextLabels => {'person'};

  @override
  int get priority => 100;

  @override
  bool shouldActivate(PluginContext context) {
    return context.hasDetectionLabel('person');
  }

  @override
  Future<PluginOutput> evaluate(PluginContext context) async {
    return const PluginOutput(
      pluginId: 'rule_of_thirds',
      overlays: [
        OverlayInstruction(type: OverlayType.ruleOfThirdsGrid),
      ],
      messages: [
        GuidanceMessage(
          title: 'Try rule of thirds',
          body: 'Place the subject near one of the grid intersections.',
        ),
      ],
    );
  }
}
