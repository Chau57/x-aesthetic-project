import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProgressChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height - 24; // Bottom offset for labels

    // Define mock data points representing progression (T2 to CN)
    final points = [
      Offset(0, height * 0.7),
      Offset(width * 0.16, height * 0.5),
      Offset(width * 0.33, height * 0.6),
      Offset(width * 0.5, height * 0.4),
      Offset(width * 0.66, height * 0.52),
      Offset(width * 0.83, height * 0.65),
      Offset(width, height * 0.45),
    ];

    // Grid baseline helpers
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, height), Offset(width, height), gridPaint);
    canvas.drawLine(
        Offset(0, height * 0.5), Offset(width, height * 0.5), gridPaint);

    // Gradient below the line
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primaryGreen.withValues(alpha: 0.18),
          AppColors.primaryGreen.withValues(alpha: 0.00),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    final fillPath = Path()
      ..moveTo(0, height)
      ..lineTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    fillPath.lineTo(width, height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Main line stroke
    final linePaint = Paint()
      ..color = AppColors.primaryGreen
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      // Bezier curve interpolation
      final controlPoint1 = Offset(
        points[i - 1].dx + (points[i].dx - points[i - 1].dx) / 2,
        points[i - 1].dy,
      );
      final controlPoint2 = Offset(
        points[i - 1].dx + (points[i].dx - points[i - 1].dx) / 2,
        points[i].dy,
      );
      linePath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        points[i].dx,
        points[i].dy,
      );
    }
    canvas.drawPath(linePath, linePaint);

    // Endpoint Indicator Circle
    final dotPaint = Paint()
      ..color = AppColors.primaryGreen
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(points.last, 6, dotPaint);
    canvas.drawCircle(points.last, 6, borderPaint);

    // Draw labels at the bottom (T2, T3, T4, T5, T6, T7, CN)
    final labelTexts = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    for (int i = 0; i < labelTexts.length; i++) {
      final textSpan = TextSpan(
        text: labelTexts[i],
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final double xPos = (i == 0)
          ? 0
          : (i == labelTexts.length - 1)
              ? width - textPainter.width
              : (i * (width / (labelTexts.length - 1))) -
                  (textPainter.width / 2);
      final double yPos = height + 6;

      textPainter.paint(canvas, Offset(xPos, yPos));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
