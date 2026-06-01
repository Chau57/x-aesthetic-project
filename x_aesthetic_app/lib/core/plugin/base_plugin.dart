import 'package:x_aesthetic_app/core/plugin/plugin_context.dart';
import 'package:x_aesthetic_app/core/plugin/plugin_output.dart';

abstract interface class AestheticPlugin {
  String get id;

  String get name;

  String get description;

  PluginStatus get status;

  Set<PluginPhase> get supportedPhases;

  Set<String> get supportedContextLabels;

  int get priority;

  bool shouldActivate(PluginContext context);

  Future<PluginOutput> evaluate(PluginContext context);
}

enum PluginStatus {
  active,
  inactive,
  experimental,
}
