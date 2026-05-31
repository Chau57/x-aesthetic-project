import 'package:flutter/material.dart';
import '../models/photo_history_item.dart';
import '../theme/app_colors.dart';
import '../widgets/score_badge.dart';

class LibraryScreen extends StatelessWidget {
  final List<PhotoHistoryItem> history;
  final VoidCallback onNavigateToCamera;

  const LibraryScreen({
    super.key,
    required this.history,
    required this.onNavigateToCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thư viện'),
      ),
      body: SafeArea(
        child: history.isEmpty
            ? _buildEmptyState()
            : GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                    left: 24, right: 24, top: 16, bottom: 90),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  return _buildPhotoGridCard(context, item);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.softGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primaryGreen,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Góc lưu trữ trống',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Những tác phẩm được lưu trữ của bạn sẽ hiển thị tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onNavigateToCamera,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Bắt đầu chụp',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGridCard(BuildContext context, PhotoHistoryItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo Image
          Image.network(
            item.imageUrl,
            fit: BoxFit.cover,
          ),

          // Top subtle gradient shadow
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45],
              ),
            ),
          ),

          // Rating score overlay badge positioned bottom-left
          Positioned(
            bottom: 10,
            left: 10,
            child: ScoreBadge(
              score: item.result.overallScore,
              fontSize: 10,
              iconSize: 11,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}
