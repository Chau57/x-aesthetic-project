import 'package:x_aesthetic_app/core/plugin/guidance_message.dart';
import 'package:x_aesthetic_app/core/plugin/overlay_instruction.dart';

class PluginOutput {
  final String pluginId;
  final List<OverlayInstruction> overlays;
  final List<GuidanceMessage> messages;
  final Map<String, double> metrics;

  const PluginOutput({
    required this.pluginId,
    this.overlays = const [],
    this.messages = const [],
    this.metrics = const {},
  });

  static PluginOutput empty(String pluginId) =>
      PluginOutput(pluginId: pluginId);
}
