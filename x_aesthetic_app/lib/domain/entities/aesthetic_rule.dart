class AestheticRule {
  final String id;
  final String name;
  final String technicalDescription;
  final bool isEnabled;

  const AestheticRule({
    required this.id,
    required this.name,
    required this.technicalDescription,
    this.isEnabled = true,
  });
}
