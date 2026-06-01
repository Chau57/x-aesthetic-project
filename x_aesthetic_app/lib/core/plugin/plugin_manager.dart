import 'package:x_aesthetic_app/core/plugin/base_plugin.dart';
import 'package:x_aesthetic_app/core/plugin/plugin_context.dart';
import 'package:x_aesthetic_app/core/plugin/plugin_output.dart';
import 'package:x_aesthetic_app/core/plugin/plugin_registry.dart';

class PluginManager {
  final PluginRegistry registry;

  const PluginManager(this.registry);

  List<AestheticPlugin> get activePlugins {
    return registry.all
        .where((plugin) => plugin.status == PluginStatus.active)
        .toList(growable: false);
  }

  Future<List<PluginOutput>> evaluate(PluginContext context) async {
    final candidates = activePlugins
        .where((plugin) => plugin.supportedPhases.contains(context.phase))
        .where((plugin) => plugin.shouldActivate(context))
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final outputs = <PluginOutput>[];
    for (final plugin in candidates) {
      outputs.add(await plugin.evaluate(context));
    }
    return outputs;
  }
}
