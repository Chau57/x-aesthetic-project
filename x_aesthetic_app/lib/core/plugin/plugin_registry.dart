import 'base_plugin.dart';

class PluginRegistry {
  final Map<String, AestheticPlugin> _plugins = {};

  List<AestheticPlugin> get all => List.unmodifiable(_plugins.values);

  AestheticPlugin? findById(String id) => _plugins[id];

  void register(AestheticPlugin plugin) {
    if (_plugins.containsKey(plugin.id)) {
      throw StateError('Plugin with id "${plugin.id}" is already registered.');
    }
    _plugins[plugin.id] = plugin;
  }

  void registerAll(Iterable<AestheticPlugin> plugins) {
    for (final plugin in plugins) {
      register(plugin);
    }
  }

  void unregister(String id) {
    _plugins.remove(id);
  }
}
