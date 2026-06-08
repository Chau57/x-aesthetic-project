import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/x_aesthetic_controller.dart';
import '../../domain/entities/captured_photo.dart';
import 'x_theme.dart';

class XBackground extends StatelessWidget {
  final Widget child;

  const XBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: context.x.backgroundGradient),
      child: child,
    );
  }
}

class XTopBar extends StatelessWidget {
  final String? title;
  final bool centerTitle;
  final IconData leadingIcon;
  final VoidCallback? onLeadingTap;
  final Widget? trailing;
  final bool showBrand;

  const XTopBar({
    this.title,
    this.centerTitle = false,
    this.leadingIcon = Icons.menu_rounded,
    this.onLeadingTap,
    this.trailing,
    this.showBrand = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onLeadingTap,
            icon: Icon(leadingIcon, color: tokens.text),
            style: IconButton.styleFrom(
              backgroundColor: tokens.isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.55),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: centerTitle
                ? Center(
                    child: Text(title ?? 'X-Aesthetic',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: tokens.text)))
                : (showBrand
                    ? const XBrandText()
                    : Text(title ?? '',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: tokens.text))),
          ),
          const SizedBox(width: 8),
          trailing ?? const ReadyPill(),
        ],
      ),
    );
  }
}

class XBrandText extends StatelessWidget {
  final double fontSize;

  const XBrandText({this.fontSize = 21, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'X-',
            style: TextStyle(
                color: tokens.primary,
                fontWeight: FontWeight.w900,
                fontSize: fontSize),
          ),
          TextSpan(
            text: 'Aesthetic',
            style: TextStyle(
                color: tokens.text,
                fontWeight: FontWeight.w900,
                fontSize: fontSize),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class ReadyPill extends StatelessWidget {
  const ReadyPill({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: tokens.isDark ? 0.72 : 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
              color: tokens.shadow, blurRadius: 14, offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 5, backgroundColor: tokens.positive),
          const SizedBox(width: 8),
          Text('Sẵn sàng',
              style: TextStyle(
                  color: tokens.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class XCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;

  const XCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 22,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ??
            tokens.surface.withValues(alpha: tokens.isDark ? 0.76 : 0.94),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
              color: tokens.shadow, blurRadius: 22, offset: const Offset(0, 12))
        ],
      ),
      child: child,
    );
  }
}

class XChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? color;

  const XChip({
    required this.icon,
    required this.label,
    this.active = false,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final accent = color ?? tokens.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? accent.withValues(alpha: 0.17)
            : tokens.surface.withValues(alpha: tokens.isDark ? 0.66 : 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: active ? accent.withValues(alpha: 0.8) : tokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 17,
              color: active ? accent : tokens.text.withValues(alpha: 0.78)),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: tokens.text)),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const PrimaryButton(
      {required this.label, this.icon, this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.check_rounded),
        label: Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.isDark ? Colors.white : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const SecondaryButton(
      {required this.label, this.icon, this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_back_rounded),
        label: Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primary,
          side: BorderSide(color: tokens.primary.withValues(alpha: 0.65)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color? color;

  const MetricTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final accent = color ?? tokens.primary;
    return XCard(
      padding: const EdgeInsets.all(12),
      radius: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 112;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: compact ? 21 : 24),
              SizedBox(height: compact ? 6 : 9),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: tokens.text,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 11.5 : 12.5),
              ),
              SizedBox(height: compact ? 2 : 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 18 : 21)),
              ),
              const Spacer(),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 10 : 11),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PhotoThumbnail extends StatelessWidget {
  final CapturedPhoto photo;
  final double scoreSize;

  const PhotoThumbnail({required this.photo, this.scoreSize = 12, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(photo.filePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _PhotoFallback()),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: tokens.surface.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(999),
                border:
                    Border.all(color: tokens.primary.withValues(alpha: 0.45)),
              ),
              child: Text(
                photo.hasEvaluation ? photo.score.toStringAsFixed(1) : 'Mới',
                style: TextStyle(
                    color: tokens.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: scoreSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Container(
      color: tokens.surface2,
      alignment: Alignment.center,
      child: Icon(Icons.image_not_supported_outlined, color: tokens.muted),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.actionLabel,
      this.onAction,
      super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                  color: tokens.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, color: tokens.primary, size: 34),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: TextStyle(
                    color: tokens.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: TextStyle(
                    color: tokens.muted,
                    height: 1.4,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              PrimaryButton(
                  label: actionLabel!,
                  icon: Icons.camera_alt_rounded,
                  onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class XLineChart extends StatelessWidget {
  final Color? color;
  final List<double> values;

  const XLineChart(
      {this.color,
      this.values = const [5.6, 7.2, 5.8, 8.1, 5.9, 5.1, 7.4],
      super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(color ?? context.x.primary, values),
      size: const Size.fromHeight(120),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final Color color;
  final List<double> values;

  _LineChartPainter(this.color, this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    for (var i = 0; i < 3; i++) {
      final y = size.height * (i + 1) / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) {
      return;
    }

    if (values.length == 1) {
      final point = _pointForValue(size, values.first, 0.5);
      final pointPaint = Paint()..color = color;
      final innerPaint = Paint()..color = Colors.white;
      canvas.drawCircle(point, 8, pointPaint);
      canvas.drawCircle(point, 4, innerPaint);
      return;
    }

    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = _yForValue(size, values[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = color;
    final innerPaint = Paint()..color = Colors.white;
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = _yForValue(size, values[i]);
      canvas.drawCircle(
          Offset(x, y), i == values.length - 1 ? 8 : 5, pointPaint);
      canvas.drawCircle(
          Offset(x, y), i == values.length - 1 ? 4 : 2.4, innerPaint);
    }
  }

  Offset _pointForValue(Size size, double value, double xFactor) {
    return Offset(size.width * xFactor, _yForValue(size, value));
  }

  double _yForValue(Size size, double value) {
    final normalized = (value / 10.0).clamp(0.0, 1.0);
    return size.height - (normalized * size.height * 0.75) - 14;
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}

class AppSnack {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class XScopeBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, XAestheticController controller)
      builder;

  const XScopeBuilder({required this.builder, super.key});

  @override
  Widget build(BuildContext context) {
    final controller = XAestheticScope.of(context);
    return AnimatedBuilder(
        animation: controller,
        builder: (context, _) => builder(context, controller));
  }
}

class CircularMastery extends StatelessWidget {
  final double value;
  final String label;
  final double size;

  const CircularMastery(
      {required this.value, required this.label, this.size = 112, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final valueFontSize = size * 0.25;
    final labelFontSize = size * 0.098;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(value: value, color: tokens.primary)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${(value * 100).round()}%',
                  style: TextStyle(
                      color: tokens.text,
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.w900)),
              Text(label,
                  style: TextStyle(
                      color: tokens.muted,
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;

  _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final base = Paint()
      ..color = Colors.grey.withValues(alpha: 0.18)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = color
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, math.pi * 2 * value, false, active);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
