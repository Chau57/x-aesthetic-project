import 'package:flutter/material.dart';
import '../models/photo_history_item.dart';
import '../models/aesthetic_result.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/factor_score_card.dart';
import '../widgets/progress_chart_painter.dart';
import '../widgets/recent_photo_tile.dart';

class ProgressScreen extends StatelessWidget {
  final List<PhotoHistoryItem> history;

  const ProgressScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    // Determine active average score or use mock defaults if empty
    final double averageScore = history.isNotEmpty
        ? (history.map((e) => e.result.overallScore).reduce((a, b) => a + b) /
            history.length)
        : 6.8;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tiến bộ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Weekly Score Summary Card inside our new reusable AppCard
              AppCard(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Điểm trung bình tuần này',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          averageScore.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.softGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                color: AppColors.primaryGreen,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '0.4 so với tuần trước',
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Custom Bezier line chart progression
                    SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: ProgressChartPainter(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 2. Section: Cải thiện theo yếu tố
              const Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Text(
                  'Cải thiện theo yếu tố',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: _FactorImprovementCard(
                      name: 'Ánh sáng',
                      delta: '+0.6',
                      icon: Icons.light_mode_outlined,
                      color: AppColors.primaryGreen,
                      bgColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _FactorImprovementCard(
                      name: 'Chủ thể',
                      delta: '+0.5',
                      icon: Icons.person_outline_rounded,
                      color: AppColors.primaryGreen,
                      bgColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _FactorImprovementCard(
                      name: 'Bố cục',
                      delta: '+0.3',
                      icon: Icons.grid_goldenratio_outlined,
                      color: AppColors.primaryGreen,
                      bgColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 3. Section: Cần luyện thêm (reusing full-width FactorScoreCard!)
              const Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Text(
                  'Cần luyện thêm',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const FactorScoreCard(
                factor: FactorScore(
                  name: 'Hậu cảnh',
                  score: 5.8,
                  status: 'Hậu cảnh hơi rối · Tập trung chụp cận cảnh',
                  needsImprovement: true,
                ),
              ),
              const SizedBox(height: 28),

              // 4. Section: Ảnh gần đây
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4.0),
                    child: Text(
                      'Ảnh gần đây',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Xem tất cả',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RecentPhotosGallery(history: history),

              // Spacing at the bottom to stay above floating bottom nav
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactorImprovementCard extends StatelessWidget {
  final String name;
  final String delta;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _FactorImprovementCard({
    required this.name,
    required this.delta,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            delta,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'tăng điểm',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPhotosGallery extends StatelessWidget {
  final List<PhotoHistoryItem> history;

  const _RecentPhotosGallery({required this.history});

  @override
  Widget build(BuildContext context) {
    // If user history is empty, show nice pre-loaded default cards so UI isn't bare
    final items = history.isNotEmpty
        ? history.reversed.toList()
        : [
            PhotoHistoryItem(
              imageUrl:
                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=300',
              createdAt: DateTime.now(),
              result: const AestheticResult(
                  overallScore: 7.2,
                  label: '',
                  summary: '',
                  factors: [],
                  suggestion: ''),
            ),
            PhotoHistoryItem(
              imageUrl:
                  'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&q=80&w=300',
              createdAt: DateTime.now(),
              result: const AestheticResult(
                  overallScore: 6.4,
                  label: '',
                  summary: '',
                  factors: [],
                  suggestion: ''),
            ),
            PhotoHistoryItem(
              imageUrl:
                  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=300',
              createdAt: DateTime.now(),
              result: const AestheticResult(
                  overallScore: 7.6,
                  label: '',
                  summary: '',
                  factors: [],
                  suggestion: ''),
            ),
            PhotoHistoryItem(
              imageUrl:
                  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=300',
              createdAt: DateTime.now(),
              result: const AestheticResult(
                  overallScore: 5.4,
                  label: '',
                  summary: '',
                  factors: [],
                  suggestion: ''),
            ),
          ];

    return SizedBox(
      height: 115,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: RecentPhotoTile(item: item),
          );
        },
      ),
    );
  }
}
