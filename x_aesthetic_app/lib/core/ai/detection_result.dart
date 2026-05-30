class DetectionResult {
  final String label;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  bool get isReliable => confidence >= 0.5;

  Map<String, Object> toJson() => {
        'label': label,
        'confidence': confidence,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}
