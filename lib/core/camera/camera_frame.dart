class CameraFrame {
  final int width;
  final int height;
  final int rotationDegrees;
  final int timestampMillis;
  final Object? rawFrame;

  const CameraFrame({
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.timestampMillis,
    this.rawFrame,
  });

  double get aspectRatio => width / height;
}
