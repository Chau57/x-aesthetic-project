import 'dart:io';

import 'package:flutter/material.dart';

import '../shared/x_theme.dart';
import '../shared/x_widgets.dart';

class PreviewScreen extends StatelessWidget {
  final VoidCallback onRetake;
  final VoidCallback onOpenGallery;

  const PreviewScreen(
      {required this.onRetake, required this.onOpenGallery, super.key});

  @override
  Widget build(BuildContext context) {
    return XScopeBuilder(
      builder: (context, app) {
        final imagePath = app.currentCapturePath ?? app.latestPhoto?.filePath;
        return XBackground(
          child: SafeArea(
            child: imagePath == null
                ? EmptyState(
                    icon: Icons.auto_graph_rounded,
                    title: 'Chưa có ảnh để phân tích',
                    subtitle:
                        'Hãy chụp một ảnh mới. Màn hình này sẽ hiển thị điểm, gợi ý và nút lưu vào thư viện riêng của ứng dụng.',
                    actionLabel: 'Mở camera',
                    onAction: onRetake,
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        XTopBar(
                          leadingIcon: Icons.arrow_back_ios_new_rounded,
                          onLeadingTap: onRetake,
                          centerTitle: true,
                          title: 'X-Aesthetic',
                          trailing: IconButton(
                              onPressed: () {},
                              icon: Icon(Icons.more_horiz_rounded,
                                  color: context.x.text)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                          child: _CapturedPhotoHero(imagePath: imagePath),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -22),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: _AnalysisSheet(
                              onRetake: onRetake,
                              onSave: () async {
                                final photo =
                                    await app.saveCurrentCaptureToLibrary();
                                if (!context.mounted) {
                                  return;
                                }
                                AppSnack.show(
                                    context,
                                    photo == null
                                        ? 'Không có ảnh để lưu.'
                                        : 'Đã lưu vào thư viện riêng của ứng dụng.');
                              },
                              onOpenGallery: onOpenGallery,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _CapturedPhotoHero extends StatelessWidget {
  final String imagePath;

  const _CapturedPhotoHero({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1.05,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _FallbackPhoto()),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.36)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            const Positioned.fill(
                child: CustomPaint(painter: _HeatmapPreviewPainter())),
          ],
        ),
      ),
    );
  }
}

class _FallbackPhoto extends StatelessWidget {
  const _FallbackPhoto();

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Container(
      color: tokens.surface2,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: tokens.muted, size: 44),
    );
  }
}

class _AnalysisSheet extends StatelessWidget {
  final VoidCallback onRetake;
  final VoidCallback onSave;
  final VoidCallback onOpenGallery;

  const _AnalysisSheet(
      {required this.onRetake,
      required this.onSave,
      required this.onOpenGallery});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return XCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                      color: tokens.muted.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 18),
          Text('Đánh giá ảnh',
              style: TextStyle(
                  color: tokens.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('7.2',
                  style: TextStyle(
                      color: tokens.primary,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      height: 1)),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                      color: tokens.primarySoft,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('Ảnh đẹp',
                      style: TextStyle(
                          color: tokens.primary, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
          Text('Khung hình tốt',
              style:
                  TextStyle(color: tokens.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                  child: MetricTile(
                      icon: Icons.wb_sunny_outlined,
                      title: 'Ánh sáng',
                      value: '7.8',
                      subtitle: 'Tốt')),
              SizedBox(width: 8),
              Expanded(
                  child: MetricTile(
                      icon: Icons.grid_on_rounded,
                      title: 'Bố cục',
                      value: '7.4',
                      subtitle: 'Tốt')),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                  child: MetricTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Chủ thể',
                      value: '8.1',
                      subtitle: 'Tốt')),
              SizedBox(width: 8),
              Expanded(
                  child: MetricTile(
                      icon: Icons.terrain_outlined,
                      title: 'Hậu cảnh',
                      value: '5.2',
                      subtitle: 'Cần cải thiện',
                      color: XColors.orange)),
            ],
          ),
          const SizedBox(height: 14),
          XCard(
            padding: const EdgeInsets.all(14),
            radius: 18,
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: tokens.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Hậu cảnh hơi rối – hãy tiến gần hơn hoặc đổi góc chụp.',
                      style: TextStyle(
                          color: tokens.text,
                          fontWeight: FontWeight.w700,
                          height: 1.35)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: SecondaryButton(
                      label: 'Chụp lại',
                      icon: Icons.camera_alt_outlined,
                      onPressed: onRetake)),
              const SizedBox(width: 12),
              Expanded(
                  child: PrimaryButton(
                      label: 'Lưu vào thư viện',
                      icon: Icons.save_alt_rounded,
                      onPressed: onSave)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                  label: 'Mở thư viện ứng dụng',
                  icon: Icons.photo_library_outlined,
                  onPressed: onOpenGallery)),
        ],
      ),
    );
  }
}

class _HeatmapPreviewPainter extends CustomPainter {
  const _HeatmapPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final spots = [
      (
        Offset(size.width * 0.62, size.height * 0.30),
        size.width * 0.13,
        XColors.greenBright.withValues(alpha: 0.34)
      ),
      (
        Offset(size.width * 0.38, size.height * 0.38),
        size.width * 0.10,
        XColors.cyan.withValues(alpha: 0.22)
      ),
      (
        Offset(size.width * 0.78, size.height * 0.25),
        size.width * 0.09,
        XColors.amber.withValues(alpha: 0.25)
      ),
    ];
    for (final spot in spots) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [spot.$3, spot.$3.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: spot.$1, radius: spot.$2));
      canvas.drawCircle(spot.$1, spot.$2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
