class AestheticAttributes {
  final Map<String, double> values;

  const AestheticAttributes(this.values);

  double operator [](String key) => values[key] ?? 0.0;

  bool contains(String key) => values.containsKey(key);

  Map<String, double> deltaTo(AestheticAttributes target) {
    final keys = {...values.keys, ...target.values.keys};
    return {
      for (final key in keys)
        key: (values[key] ?? 0.0) - (target.values[key] ?? 0.0),
    };
  }

  Map<String, Object> toJson() => values;
}
