import 'package:flutter/material.dart';
import '../models/camera_enums.dart';
import '../theme/app_colors.dart';

/// A modal bottom sheet that lets the user pick a [CameraAspectRatio].
class AspectRatioSheet extends StatelessWidget {
  final CameraAspectRatio current;
  final ValueChanged<CameraAspectRatio> onSelected;

  const AspectRatioSheet({
    super.key,
    required this.current,
    required this.onSelected,
  });

  /// Convenience method to show this sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required CameraAspectRatio current,
    required ValueChanged<CameraAspectRatio> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AspectRatioSheet(
        current: current,
        onSelected: onSelected,
      ),
    );
  }

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
          // Drag handle
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

          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tỉ lệ khung hình',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),

          // Ratio options
          ...CameraAspectRatio.values.map((ratio) {
            final isSelected = ratio == current;
            return InkWell(
              onTap: () {
                onSelected(ratio);
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 14.0,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      ratio.label,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
