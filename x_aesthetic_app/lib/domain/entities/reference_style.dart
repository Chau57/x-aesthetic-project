import 'package:x_aesthetic_app/core/ai/aesthetic_attributes.dart';

class ReferenceStyle {
  final String id;
  final String name;
  final String description;
  final AestheticAttributes targetAttributes;
  final Map<String, Object> metadata;

  const ReferenceStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.targetAttributes,
    this.metadata = const {},
  });
}
