import 'package:flutter_test/flutter_test.dart';
import 'package:x_aesthetic_app/core/camera/horizon_math.dart';

void main() {
  group('horizon math', () {
    test('reads level axes from accelerometer x/y projection', () {
      expect(
        deviceRollDegreesFromAccelerometer(x: 0, y: 9.8),
        closeTo(0, 0.001),
      );
      expect(
        deviceRollDegreesFromAccelerometer(x: 9.8, y: 0),
        closeTo(90, 0.001),
      );
      expect(
        deviceRollDegreesFromAccelerometer(x: 0, y: -9.8),
        closeTo(180, 0.001),
      );
      expect(
        deviceRollDegreesFromAccelerometer(x: -9.8, y: 0),
        closeTo(-90, 0.001),
      );
    });

    test('measures error from the nearest level hold orientation', () {
      expect(horizonLevelErrorDegrees(0), closeTo(0, 0.001));
      expect(horizonLevelErrorDegrees(90), closeTo(0, 0.001));
      expect(horizonLevelErrorDegrees(180), closeTo(0, 0.001));
      expect(horizonLevelErrorDegrees(-90), closeTo(0, 0.001));
      expect(horizonLevelErrorDegrees(12), closeTo(12, 0.001));
      expect(horizonLevelErrorDegrees(102), closeTo(12, 0.001));
      expect(horizonLevelErrorDegrees(178), closeTo(-2, 0.001));
    });

    test('rotates display line opposite to device roll error', () {
      expect(horizonDisplayRotationDegrees(10), closeTo(-10, 0.001));
      expect(horizonDisplayRotationDegrees(-10), closeTo(10, 0.001));
      expect(horizonDisplayRotationDegrees(95), closeTo(-5, 0.001));
      expect(horizonDisplayRotationDegrees(-95), closeTo(5, 0.001));
      expect(horizonDisplayRotationDegrees(178), closeTo(2, 0.001));
    });
  });
}
