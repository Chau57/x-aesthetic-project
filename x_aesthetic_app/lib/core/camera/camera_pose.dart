class CameraPose {
  final double rollDegrees;
  final double pitchDegrees;
  final double yawDegrees;

  const CameraPose({
    this.rollDegrees = 0,
    this.pitchDegrees = 0,
    this.yawDegrees = 0,
  });

  bool isLevel({double toleranceDegrees = 2.0}) {
    return rollDegrees.abs() <= toleranceDegrees;
  }
}
