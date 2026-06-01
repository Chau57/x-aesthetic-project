import 'package:flutter/material.dart';

/// Draws a ghost subject-placement silhouette for the retake-guide mode.
///
/// [suggestedSubjectBounds] uses normalised coordinates (0.0–1.0) that are
/// scaled to the actual canvas size at paint time.
class GhostOutlinePainter extends CustomPainter {
  final Rect suggestedSubjectBounds;

  GhostOutlinePainter({required this.suggestedSubjectBounds});

  @override
  void paint(Canvas canvas, Size size) {
    // --- Stroke style (subtle, soft green-white, thin) ----------------------
    final paint = Paint()
      ..color = const Color(0xB3E8F5E9) // soft green-white, ~0.50 opacity
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Scale normalised bounds to canvas pixels
    final double left = suggestedSubjectBounds.left * size.width;
    final double top = suggestedSubjectBounds.top * size.height;
    final double width = suggestedSubjectBounds.width * size.width;
    final double height = suggestedSubjectBounds.height * size.height;

    final Rect actual = Rect.fromLTWH(left, top, width, height);

    // --- Head oval -----------------------------------------------------------
    final centerX = actual.center.dx;
    final headH = actual.height * 0.40;
    final headW = actual.width * 0.50;

    final headRect = Rect.fromCenter(
      center: Offset(centerX, actual.top + headH * 0.55),
      width: headW,
      height: headH,
    );
    canvas.drawOval(headRect, paint);

    // --- Shoulder curves -----------------------------------------------------
    final path = Path();
    final double neckLeftX = centerX - headW * 0.25;
    final double neckRightX = centerX + headW * 0.25;
    final double neckY = actual.top + headH;

    // Left shoulder
    path.moveTo(neckLeftX, neckY);
    path.quadraticBezierTo(
      actual.left + actual.width * 0.12,
      neckY + actual.height * 0.10,
      actual.left,
      actual.bottom,
    );

    // Right shoulder
    path.moveTo(neckRightX, neckY);
    path.quadraticBezierTo(
      actual.right - actual.width * 0.12,
      neckY + actual.height * 0.10,
      actual.right,
      actual.bottom,
    );

    canvas.drawPath(path, paint);

    // --- Dashed bounding box ------------------------------------------------
    final boxPaint = Paint()
      ..color = const Color(0x40FFFFFF) // white ~0.25 opacity
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    _drawDashedRect(canvas, actual, boxPaint, 6, 4);
  }

  void _drawDashedRect(
      Canvas canvas, Rect rect, Paint paint, double dashW, double dashSpace) {
    final Path path = Path()..addRect(rect);
    final Path dashed = Path();

    double distance = 0.0;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final double next = distance + dashW;
        dashed.addPath(
          metric.extractPath(
              distance, next < metric.length ? next : metric.length),
          Offset.zero,
        );
        distance = next + dashSpace;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant GhostOutlinePainter oldDelegate) {
    return oldDelegate.suggestedSubjectBounds != suggestedSubjectBounds;
  }
}
