import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/overlay_options.dart';

class CameraOverlayPainter extends CustomPainter {
  final OverlayOptions options;
  final double tiltAngle; // For simulated horizon line interaction if any

  CameraOverlayPainter({required this.options, this.tiltAngle = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Rule of Thirds Grid
    if (options.ruleOfThirds) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      // Vertical lines
      canvas.drawLine(Offset(size.width / 3, 0),
          Offset(size.width / 3, size.height), paint);
      canvas.drawLine(Offset(2 * size.width / 3, 0),
          Offset(2 * size.width / 3, size.height), paint);

      // Horizontal lines
      canvas.drawLine(Offset(0, size.height / 3),
          Offset(size.width, size.height / 3), paint);
      canvas.drawLine(Offset(0, 2 * size.height / 3),
          Offset(size.width, 2 * size.height / 3), paint);
    }

    // 2. Horizon Stabilizer Line
    if (options.horizonLine) {
      final paint = Paint()
        ..color = (tiltAngle.abs() < 0.02)
            ? const Color(0xFF2F6B3F)
            : Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final double centerY = size.height / 2;
      final double startX = size.width * 0.15;
      final double endX = size.width * 0.85;

      // Draw active horizontal guide line with slight rotation if tilted
      canvas.save();
      canvas.translate(size.width / 2, centerY);
      canvas.rotate(tiltAngle);
      canvas.drawLine(Offset(startX - size.width / 2, 0),
          Offset(endX - size.width / 2, 0), paint);

      // Center stabilizer circle
      final circlePaint = Paint()
        ..color = (tiltAngle.abs() < 0.02)
            ? const Color(0xFF2F6B3F)
            : Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset.zero, 8, circlePaint);

      canvas.restore();
    }

    // 3. Suggested Framing Box (Dashed rounded rectangle in the center)
    if (options.suggestedFrame) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final double boxWidth = size.width * 0.7;
      final double boxHeight = size.height * 0.6;
      final double left = (size.width - boxWidth) / 2;
      final double top = (size.height - boxHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, boxWidth, boxHeight),
        const Radius.circular(24),
      );

      _drawDashedRRect(canvas, rect, paint, 8, 4);
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint,
      double dashWidth, double dashSpace) {
    final Path path = Path()..addRRect(rrect);
    final Path dashedPath = Path();

    double distance = 0.0;
    for (final PathMetric measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        final double nextDistance = distance + dashWidth;
        dashedPath.addPath(
          measurePath.extractPath(
              distance,
              nextDistance < measurePath.length
                  ? nextDistance
                  : measurePath.length),
          Offset.zero,
        );
        distance = nextDistance + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CameraOverlayPainter oldDelegate) {
    return oldDelegate.options != options || oldDelegate.tiltAngle != tiltAngle;
  }
}
