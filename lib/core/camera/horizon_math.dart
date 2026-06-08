import 'dart:math' as math;

double normalizeDegrees180(double value) {
  var result = value;
  while (result > 180) {
    result -= 360;
  }
  while (result <= -180) {
    result += 360;
  }
  return result;
}

double deviceRollDegreesFromAccelerometer({
  required double x,
  required double y,
}) {
  if (!x.isFinite || !y.isFinite) {
    return 0;
  }
  return normalizeDegrees180(math.atan2(x, y) * 180 / math.pi);
}

double horizonLevelErrorDegrees(double rollDegrees) {
  final normalized = normalizeDegrees180(rollDegrees);
  final nearestLevelAxis = (normalized / 90).round() * 90;
  return normalizeDegrees180(normalized - nearestLevelAxis);
}

double horizonDisplayRotationDegrees(double rollDegrees) {
  return normalizeDegrees180(rollDegrees);
}
