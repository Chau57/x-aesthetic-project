import 'package:flutter/material.dart';
import 'package:x_aesthetic_app/domain/entities/overlay_options.dart';
import 'package:x_aesthetic_app/presentation/theme/app_colors.dart';
import 'package:x_aesthetic_app/presentation/widgets/guide_toggle_tile.dart';

class OverlayGuideSheet extends StatelessWidget {
  final OverlayOptions options;
  final ValueChanged<OverlayOptions> onChanged;

  const OverlayGuideSheet({
    super.key,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle indicator
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header title row
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Text(
                  'Hướng dẫn bố cục',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dividers and switch toggles using reusable GuideToggleTile
          const Divider(color: AppColors.border, height: 1),

          GuideToggleTile(
            icon: Icons.grid_goldenratio_outlined,
            title: 'Lưới 1/3',
            value: options.ruleOfThirds,
            onChanged: (val) {
              onChanged(options.copyWith(ruleOfThirds: val));
            },
          ),
          GuideToggleTile(
            icon: Icons.horizontal_rule_rounded,
            title: 'Đường chân trời',
            value: options.horizonLine,
            onChanged: (val) {
              onChanged(options.copyWith(horizonLine: val));
            },
          ),
          GuideToggleTile(
            icon: Icons.crop_free_rounded,
            title: 'Khung gợi ý',
            value: options.suggestedFrame,
            onChanged: (val) {
              onChanged(options.copyWith(suggestedFrame: val));
            },
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Footer descriptive note
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.textSecondary, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Viền gợi ý sẽ xuất hiện khi bạn chọn Chụp lại theo gợi ý.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
