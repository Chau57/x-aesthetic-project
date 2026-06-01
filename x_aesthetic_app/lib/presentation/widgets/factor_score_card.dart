import 'package:flutter/material.dart';
import 'package:x_aesthetic_app/presentation/theme/app_colors.dart';
import 'package:x_aesthetic_app/domain/entities/aesthetic_result.dart';

class FactorScoreCard extends StatelessWidget {
  final FactorScore factor;
  final bool isCompactColumn;

  const FactorScoreCard({
    super.key,
    required this.factor,
    this.isCompactColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool warning = factor.needsImprovement;
    final Color bgColor = warning ? AppColors.softOrange : AppColors.softGreen;
    final Color accentColor =
        warning ? AppColors.warningOrange : AppColors.primaryGreen;

    // Choose appropriate visual icon
    IconData iconData = Icons.star_border_rounded;
    if (factor.name.contains('Ánh sáng') ||
        factor.name.toLowerCase().contains('light')) {
      iconData = Icons.light_mode_outlined;
    } else if (factor.name.contains('Bố cục') ||
        factor.name.toLowerCase().contains('composition')) {
      iconData = Icons.grid_goldenratio_outlined;
    } else if (factor.name.contains('Chủ thể') ||
        factor.name.toLowerCase().contains('subject')) {
      iconData = Icons.person_outline_rounded;
    } else if (factor.name.contains('Hậu cảnh') ||
        factor.name.toLowerCase().contains('background')) {
      iconData = Icons.landscape_outlined;
    }

    // 1. Compact Column Layout (For horizontal grids like Preview diagnostics)
    if (isCompactColumn) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: accentColor.withValues(alpha: 0.1), width: 1.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, color: accentColor, size: 20),
            const SizedBox(height: 6),
            Text(
              factor.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              factor.score.toStringAsFixed(1),
              style: TextStyle(
                color: accentColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              factor.status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accentColor,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // 2. Row List Layout (For dashboard lists like Progress screen)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.1), width: 1.0),
      ),
      child: Row(
        children: [
          // Icon Circle
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Name and Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factor.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  factor.status,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Score Label
          Text(
            factor.score.toStringAsFixed(1),
            style: TextStyle(
              color: accentColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
