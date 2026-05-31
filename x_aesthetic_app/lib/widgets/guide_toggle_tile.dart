import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GuideToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const GuideToggleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: [
          // Elegant Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
          const SizedBox(width: 16),
          // Title Label
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Premium Minimal Switch Toggle
          Switch(
            value: value,
            activeThumbColor: AppColors.primaryGreen,
            activeTrackColor: AppColors.softGreen,
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.border,
            trackOutlineColor: WidgetStateProperty.resolveWith(
              (states) => Colors.transparent,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
