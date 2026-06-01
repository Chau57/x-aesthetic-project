import 'package:flutter/material.dart';
import 'package:x_aesthetic_app/domain/entities/aesthetic_result.dart';
import 'package:x_aesthetic_app/domain/entities/camera_enums.dart';
import 'package:x_aesthetic_app/domain/entities/photo_history_item.dart';
import 'package:x_aesthetic_app/presentation/theme/app_colors.dart';
import 'package:x_aesthetic_app/data/mock_data.dart';
import 'package:x_aesthetic_app/presentation/widgets/app_card.dart';
import 'package:x_aesthetic_app/presentation/widgets/score_badge.dart';
import 'package:x_aesthetic_app/presentation/widgets/factor_score_card.dart';
import 'package:x_aesthetic_app/presentation/widgets/primary_button.dart';
import 'package:x_aesthetic_app/presentation/widgets/secondary_button.dart';
import 'package:x_aesthetic_app/presentation/screens/camera_screen.dart';

class PreviewResultScreen extends StatelessWidget {
  final String imageUrl;
  final AestheticResult result;
  final ValueChanged<PhotoHistoryItem> onSave;

  const PreviewResultScreen({
    super.key,
    required this.imageUrl,
    required this.result,
    required this.onSave,
  });

  void _handleSave(BuildContext context) {
    // Construct new history item record matching revised parameters
    final item = PhotoHistoryItem(
      imageUrl: imageUrl,
      result: result,
      createdAt: DateTime.now(),
    );

    // Invoke save callback
    onSave(item);

    // Show beautiful success SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Đã lưu thành công vào Thư viện',
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
      ),
    );

    // Go back to core navigation shell
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Xem lại ảnh'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Photo Preview Card with rounded borders and deep shadow
              Container(
                height: 330,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),

              // 2. Evaluation Diagnostics Card (AppCard)
              AppCard(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đánh giá thẩm mỹ',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Overall score badge (Typography style)
                    ScoreBadge(
                      score: result.overallScore,
                      label: result.label,
                      summary: result.summary,
                    ),
                    const SizedBox(height: 24),

                    // Modular horizontal grids using unified FactorScoreCard
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: result.factors.map((factor) {
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: FactorScoreCard(
                              factor: factor,
                              isCompactColumn: true,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Suggestion Tip Box (DSLR tip card style)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: AppColors.warningOrange,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              result.suggestion,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 3. Action Buttons with clear visual hierarchy
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: 'Chụp lại',
                      icon: Icons.refresh_rounded,
                      onPressed: () {
                        // Open CameraScreen in retakeGuide mode with ghost outlines
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CameraScreen(
                              mode: CameraMode.retakeGuide,
                              previousImageUrl: imageUrl,
                              retakeGuide: MockData.retakeGuide,
                              history: const [],
                              onSavePhoto: onSave,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: PrimaryButton(
                      text: 'Lưu vào thư viện',
                      icon: Icons.check_rounded,
                      onPressed: () => _handleSave(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
