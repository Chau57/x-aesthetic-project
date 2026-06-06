import 'package:flutter/material.dart';

import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/photo_context.dart';
import '../shared/x_theme.dart';
import '../shared/x_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return XScopeBuilder(
      builder: (context, app) {
        final photos = app.photos;
        final stats = _ProgressStats.fromPhotos(photos);
        return XBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 132),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SimpleHeader(title: 'Tiến độ'),
                  const SizedBox(height: 4),
                  _WeeklyScoreCard(stats: stats),
                  const SizedBox(height: 18),
                  const _SectionTitle(title: 'Cải thiện theo yếu tố'),
                  const SizedBox(height: 10),
                  _FactorGrid(stats: stats),
                  const SizedBox(height: 18),
                  const _SectionTitle(title: 'Bối cảnh đã luyện'),
                  const SizedBox(height: 10),
                  _ContextDistributionCard(stats: stats),
                  const SizedBox(height: 18),
                  const _SectionTitle(title: 'Cần luyện thêm'),
                  const SizedBox(height: 10),
                  _NeedPracticeCard(stats: stats),
                  const SizedBox(height: 18),
                  _SectionTitle(
                      title: 'Ảnh gần đây',
                      action: photos.isEmpty ? null : '${photos.length} ảnh'),
                  const SizedBox(height: 10),
                  if (photos.isEmpty)
                    XCard(
                      child: Text(
                        'Chưa có ảnh nào trong thư viện ứng dụng. Hãy chụp, đánh giá và lưu ảnh để dashboard cập nhật dữ liệu thật.',
                        style: TextStyle(
                            color: context.x.muted,
                            height: 1.4,
                            fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.take(8).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => SizedBox(
                            width: 86,
                            child: PhotoThumbnail(photo: photos[index])),
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

class _ProgressStats {
  final List<CapturedPhoto> photos;
  final int totalPhotos;
  final int weekPhotos;
  final double weekAverage;
  final double previousWeekAverage;
  final double delta;
  final Map<String, double> metricAverages;
  final Map<PhotoContext, int> contextCounts;
  final List<double> chartValues;
  final String needPracticeMetric;
  final double needPracticeScore;

  const _ProgressStats({
    required this.photos,
    required this.totalPhotos,
    required this.weekPhotos,
    required this.weekAverage,
    required this.previousWeekAverage,
    required this.delta,
    required this.metricAverages,
    required this.contextCounts,
    required this.chartValues,
    required this.needPracticeMetric,
    required this.needPracticeScore,
  });

  factory _ProgressStats.fromPhotos(List<CapturedPhoto> photos) {
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));
    final previousWeekStart = now.subtract(const Duration(days: 14));
    final week = photos
        .where((photo) =>
            photo.createdAt.isAfter(weekStart) && photo.hasEvaluation)
        .toList();
    final previousWeek = photos
        .where((photo) =>
            photo.createdAt.isAfter(previousWeekStart) &&
            photo.createdAt.isBefore(weekStart) &&
            photo.hasEvaluation)
        .toList();

    final weekAverage = _average(week.map((photo) => photo.score));
    final previousAverage = _average(previousWeek.map((photo) => photo.score));
    final metricKeys = <String>{};
    for (final photo in photos.where((photo) => photo.hasEvaluation)) {
      metricKeys.addAll(photo.metrics.keys);
    }
    final metricAverages = <String, double>{};
    for (final key in metricKeys) {
      metricAverages[key] = _average(
          photos.map((photo) => photo.metrics[key]).whereType<double>());
    }

    final contextCounts = <PhotoContext, int>{};
    for (final photo in photos.where((photo) => photo.hasEvaluation)) {
      final context = photo.evaluation.contextAnalysis.resolvedContext;
      contextCounts[context] = (contextCounts[context] ?? 0) + 1;
    }

    var needKey = 'Ánh sáng';
    var needValue = metricAverages[needKey] ?? 0;
    for (final entry in metricAverages.entries) {
      if (needValue == 0 || entry.value < needValue) {
        needKey = entry.key;
        needValue = entry.value;
      }
    }

    final chart = List<double>.generate(7, (index) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - index));
      final next = day.add(const Duration(days: 1));
      final dayPhotos = photos.where((photo) =>
          photo.createdAt.isAfter(day) &&
          photo.createdAt.isBefore(next) &&
          photo.hasEvaluation);
      return _average(dayPhotos.map((photo) => photo.score));
    });

    return _ProgressStats(
      photos: photos,
      totalPhotos: photos.length,
      weekPhotos: week.length,
      weekAverage: weekAverage,
      previousWeekAverage: previousAverage,
      delta: previousAverage == 0 ? 0 : weekAverage - previousAverage,
      metricAverages: metricAverages,
      contextCounts: contextCounts,
      chartValues: chart.every((value) => value == 0)
          ? const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
          : chart,
      needPracticeMetric: needKey,
      needPracticeScore: needValue,
    );
  }

  static double _average(Iterable<double> values) {
    final list = values.where((value) => value > 0).toList();
    if (list.isEmpty) {
      return 0;
    }
    return list.reduce((a, b) => a + b) / list.length;
  }
}

class _SimpleHeader extends StatelessWidget {
  final String title;

  const _SimpleHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Center(
        child: Text(title,
            style: TextStyle(
                color: tokens.text, fontSize: 22, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _WeeklyScoreCard extends StatelessWidget {
  final _ProgressStats stats;

  const _WeeklyScoreCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final hasData = stats.weekAverage > 0;
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 340;
              final scoreInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Điểm trung bình tuần này',
                      style: TextStyle(
                          color: tokens.text, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            hasData
                                ? stats.weekAverage.toStringAsFixed(1)
                                : '--',
                            style: TextStyle(
                                color: tokens.primary,
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                height: 1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                              color: tokens.primarySoft,
                              borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            hasData
                                ? '${stats.delta >= 0 ? '↑' : '↓'} ${stats.delta.abs().toStringAsFixed(1)} so với tuần trước'
                                : '${stats.totalPhotos} ảnh đã lưu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: tokens.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${stats.weekPhotos} ảnh được đánh giá trong 7 ngày qua',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: tokens.muted, fontWeight: FontWeight.w700),
                  ),
                ],
              );
              final mastery = CircularMastery(
                size: compact ? 92 : 104,
                value: (stats.weekAverage / 10).clamp(0.0, 1.0).toDouble(),
                label: 'Mức ổn định\nkỹ thuật',
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    scoreInfo,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: mastery),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: scoreInfo),
                  const SizedBox(width: 10),
                  mastery,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          XLineChart(values: stats.chartValues),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                .map((day) => Text(day,
                    style: TextStyle(
                        color: tokens.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FactorGrid extends StatelessWidget {
  final _ProgressStats stats;

  const _FactorGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final entries = stats.metricAverages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topMetrics = entries.take(4).toList();
    final children = topMetrics.isEmpty
        ? const [
            MetricTile(
                icon: Icons.wb_sunny_outlined,
                title: 'Ánh sáng',
                value: '--',
                subtitle: 'trung bình'),
            MetricTile(
                icon: Icons.grid_on_rounded,
                title: 'Bố cục',
                value: '--',
                subtitle: 'trung bình'),
            MetricTile(
                icon: Icons.palette_outlined,
                title: 'Màu sắc',
                value: '--',
                subtitle: 'trung bình'),
            MetricTile(
                icon: Icons.straighten_rounded,
                title: 'Cân bằng',
                value: '--',
                subtitle: 'trung bình'),
          ]
        : topMetrics
            .map(
              (entry) => MetricTile(
                icon: _iconForMetric(entry.key),
                title: entry.key,
                value: entry.value.toStringAsFixed(1),
                subtitle: 'trung bình',
              ),
            )
            .toList();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.22,
      children: children,
    );
  }
}

class _ContextDistributionCard extends StatelessWidget {
  final _ProgressStats stats;

  const _ContextDistributionCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final entries = stats.contextCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return XCard(
        child: Text(
          'Chưa có bối cảnh nào được ghi nhận. Hãy chụp và đánh giá ảnh theo ngữ cảnh để dashboard cập nhật.',
          style: TextStyle(
              color: tokens.muted, fontWeight: FontWeight.w700, height: 1.35),
        ),
      );
    }
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    return XCard(
      child: Column(
        children: entries.take(5).map((entry) {
          final ratio = total == 0 ? 0.0 : entry.value / total;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Icon(_iconForContext(entry.key),
                    color: tokens.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key.label,
                          style: TextStyle(
                              color: tokens.text, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          color: tokens.primary,
                          backgroundColor: tokens.primarySoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('${entry.value}',
                    style: TextStyle(
                        color: tokens.muted, fontWeight: FontWeight.w900)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

IconData _iconForContext(PhotoContext context) {
  switch (context) {
    case PhotoContext.portrait:
      return Icons.person_outline_rounded;
    case PhotoContext.landscape:
      return Icons.landscape_outlined;
    case PhotoContext.street:
      return Icons.directions_walk_rounded;
    case PhotoContext.architecture:
      return Icons.apartment_rounded;
    case PhotoContext.food:
      return Icons.restaurant_rounded;
    case PhotoContext.product:
      return Icons.inventory_2_outlined;
    case PhotoContext.macro:
      return Icons.center_focus_strong_rounded;
    case PhotoContext.animal:
      return Icons.pets_rounded;
    case PhotoContext.night:
      return Icons.nightlight_round;
    case PhotoContext.auto:
    case PhotoContext.general:
      return Icons.auto_awesome_mosaic_rounded;
  }
}

IconData _iconForMetric(String metric) {
  switch (metric) {
    case 'Ánh sáng':
    case 'Dải sáng':
      return Icons.wb_sunny_outlined;
    case 'Cân bằng':
    case 'Đường chân trời':
    case 'Đường thẳng':
    case 'Phối cảnh':
      return Icons.straighten_rounded;
    case 'Tương phản':
    case 'Vùng sáng':
    case 'Chi tiết tối':
      return Icons.contrast_rounded;
    case 'Màu sắc':
      return Icons.palette_outlined;
    case 'Bố cục':
    case 'Đối xứng':
    case 'Đường dẫn':
      return Icons.grid_on_rounded;
    case 'Chủ thể':
    case 'Khoảnh khắc':
      return Icons.center_focus_strong_rounded;
    case 'Hậu cảnh':
    case 'Nền':
    case 'Nền mờ':
      return Icons.layers_outlined;
    case 'Chiều sâu':
      return Icons.landscape_outlined;
    case 'HDR':
      return Icons.hdr_strong_rounded;
    default:
      return Icons.auto_graph_rounded;
  }
}

class _NeedPracticeCard extends StatelessWidget {
  final _ProgressStats stats;

  const _NeedPracticeCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final hasData = stats.needPracticeScore > 0;
    return XCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
                color: XColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18)),
            child: Icon(_metricIcon(stats.needPracticeMetric),
                color: XColors.orange, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasData ? stats.needPracticeMetric : 'Chưa đủ dữ liệu',
                    style: TextStyle(
                        color: tokens.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
                const SizedBox(height: 3),
                Text(
                    hasData ? stats.needPracticeScore.toStringAsFixed(1) : '--',
                    style: const TextStyle(
                        color: XColors.orange,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        height: 1)),
                Text(
                    hasData
                        ? 'Điểm thấp nhất hiện tại'
                        : 'Hãy đánh giá thêm ảnh để tạo lộ trình.',
                    style: TextStyle(
                        color: tokens.muted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tokens.muted),
        ],
      ),
    );
  }

  IconData _metricIcon(String metric) => _iconForMetric(metric);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;

  const _SectionTitle({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Row(
      children: [
        Expanded(
            child: Text(title,
                style: TextStyle(
                    color: tokens.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900))),
        if (action != null)
          Text(action!,
              style: TextStyle(
                  color: tokens.primary, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
