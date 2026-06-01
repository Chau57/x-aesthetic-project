import 'package:flutter/material.dart';
import 'package:x_aesthetic_app/presentation/theme/app_colors.dart';

class ScoreBadge extends StatelessWidget {
  final double score;
  final String? label;
  final String? summary;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const ScoreBadge({
    super.key,
    required this.score,
    this.label,
    this.summary,
    this.fontSize = 12,
    this.iconSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    // Determine dynamic category colors based on score threshold
    Color accentColor = AppColors.primaryGreen;
    Color bgColor = AppColors.softGreen;

    if (score < 6.0) {
      accentColor = AppColors.warningOrange;
      bgColor = AppColors.softOrange;
    } else if (score < 7.0) {
      accentColor = const Color(0xFFD48D2A); // Muted Amber
      bgColor = const Color(0xFFFEF8EC); // Soft Amber Tint
    }

    // 1. Detailed Header Style (If label/summary are provided)
    if (label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  color: accentColor,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: accentColor.withValues(alpha: 0.1), width: 1.0),
                ),
                child: Text(
                  label!,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: 4),
            Text(
              summary!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      );
    }

    // 2. Compact Pill Star Badge Style
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.1), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            color: accentColor,
            size: iconSize,
          ),
          const SizedBox(width: 4),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              color: accentColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
