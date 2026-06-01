import 'package:flutter/material.dart';
import 'package:x_aesthetic_app/domain/entities/camera_enums.dart';
import 'package:x_aesthetic_app/domain/entities/photo_history_item.dart';
import 'package:x_aesthetic_app/data/mock_data.dart';
import 'package:x_aesthetic_app/presentation/theme/app_colors.dart';
import 'package:x_aesthetic_app/presentation/widgets/score_badge.dart';
import 'package:x_aesthetic_app/presentation/screens/camera_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<PhotoHistoryItem> history;
  final VoidCallback onOpenCamera;
  final ValueChanged<PhotoHistoryItem> onSavePhoto;

  const HomeScreen({
    super.key,
    required this.history,
    required this.onOpenCamera,
    required this.onSavePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreetingMessage();
    final lastItem = history.isNotEmpty ? history.last : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        centerTitle: false,
        titleSpacing: 24,
        title: const Text(
          'Trang chủ',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
              ),
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GreetingBlock(greeting: greeting),
              const SizedBox(height: 22),
              _HeroCameraCard(onOpenCamera: onOpenCamera),
              const SizedBox(height: 18),
              _DailyPracticeCard(onOpenCamera: onOpenCamera),
              if (lastItem != null) ...[
                const SizedBox(height: 22),
                _RetakeSuggestionCard(
                  item: lastItem,
                  onSavePhoto: onSavePhoto,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }
}

class _GreetingBlock extends StatelessWidget {
  final String greeting;

  const _GreetingBlock({required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: const TextStyle(
            color: AppColors.primaryGreen,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sẵn sàng cải thiện\nbức ảnh tiếp theo?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 30,
            height: 1.12,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.9,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Chụp ảnh, nhận đánh giá và thử lại với gợi ý bố cục trực quan.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _HeroCameraCard extends StatelessWidget {
  final VoidCallback onOpenCamera;

  const _HeroCameraCard({required this.onOpenCamera});

  @override
  Widget build(BuildContext context) {
    return Container(
      height:
          250, // Adjusted to 250 to cleanly prevent vertical RenderFlex / content overflows
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative soft circles
          Positioned(
            right: -44,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeroBadge(),
                const Spacer(),
                const Text(
                  'Chụp ảnh\nvà nhận gợi ý',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Camera sẽ chỉ hiển thị overlay bố cục nhẹ. Kết quả đánh giá xuất hiện sau khi chụp.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onOpenCamera,
                    icon: const Icon(Icons.camera_alt_rounded, size: 19),
                    label: const Text('Mở camera'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
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

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.grid_3x3_rounded,
            size: 14,
            color: Colors.white.withValues(alpha: 0.92),
          ),
          const SizedBox(width: 7),
          Text(
            'Overlay bố cục nhẹ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;

    // Only draw right-side guide lines so the text area stays clean.
    final left = size.width * 0.58;
    final right = size.width + 10;
    final top = size.height * 0.18;
    final bottom = size.height * 0.82;

    final guideRect = Rect.fromLTRB(left, top, right, bottom);

    for (int i = 1; i < 3; i++) {
      final dx = guideRect.left + guideRect.width * i / 3;
      final dy = guideRect.top + guideRect.height * i / 3;

      canvas.drawLine(
        Offset(dx, guideRect.top),
        Offset(dx, guideRect.bottom),
        linePaint,
      );

      canvas.drawLine(
        Offset(guideRect.left, dy),
        Offset(guideRect.right, dy),
        linePaint,
      );
    }

    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final frame = Rect.fromLTWH(
      size.width * 0.68,
      size.height * 0.30,
      size.width * 0.22,
      size.height * 0.42,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(24)),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DailyPracticeCard extends StatelessWidget {
  final VoidCallback onOpenCamera;

  const _DailyPracticeCard({required this.onOpenCamera});

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.softOrange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.warningOrange,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Luyện nhanh hôm nay',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Thử đặt chủ thể gần giao điểm 1/3 để khung hình cân bằng hơn.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: onOpenCamera,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Thử ngay'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.primaryGreen,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
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

class _RetakeSuggestionCard extends StatelessWidget {
  final PhotoHistoryItem item;
  final ValueChanged<PhotoHistoryItem> onSavePhoto;

  const _RetakeSuggestionCard({
    required this.item,
    required this.onSavePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final factorToImprove = item.result.factors.firstWhere(
      (factor) => factor.needsImprovement,
      orElse: () => item.result.factors.last,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tiếp tục cải thiện',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        _HomeCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 96,
                    height: 134,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      image: DecorationImage(
                        image: NetworkImage(item.imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: ScoreBadge(
                      score: item.result.overallScore,
                      fontSize: 10,
                      iconSize: 12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MiniChip(
                      icon: Icons.auto_awesome_rounded,
                      text: 'Gợi ý từ ảnh trước',
                      background: AppColors.softGreen,
                      foreground: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Cải thiện ${factorToImprove.name.toLowerCase()}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.result.suggestion,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CameraScreen(
                                mode: CameraMode.retakeGuide,
                                previousImageUrl: item.imageUrl,
                                retakeGuide: MockData.retakeGuide,
                                history: const [],
                                onSavePhoto: onSavePhoto,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Chụp lại'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _HomeCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  const _MiniChip({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
