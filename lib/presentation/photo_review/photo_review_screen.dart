import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/x_aesthetic_controller.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/photo_context.dart';
import '../../services/analysis/rule_based_photo_evaluator.dart';
import '../shared/x_theme.dart';
import '../shared/x_widgets.dart';

class PhotoReviewScreen extends StatefulWidget {
  final String imagePath;
  final bool canSave;
  final VoidCallback onClose;
  final VoidCallback onRetake;

  const PhotoReviewScreen({
    required this.imagePath,
    required this.canSave,
    required this.onClose,
    required this.onRetake,
    super.key,
  });

  @override
  State<PhotoReviewScreen> createState() => _PhotoReviewScreenState();
}

class _PhotoReviewScreenState extends State<PhotoReviewScreen> {
  final RuleBasedPhotoEvaluator _evaluator = const RuleBasedPhotoEvaluator();
  bool _showAnalysis = false;
  bool _saved = false;
  bool _saving = false;
  bool _evaluating = false;
  PhotoEvaluation? _evaluation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final photo = XAestheticScope.of(context).findPhotoByPath(widget.imagePath);
    if (photo != null && photo.hasEvaluation) {
      _evaluation ??= photo.evaluation;
    }
  }

  CaptureMetadata? _currentMetadata() {
    final app = XAestheticScope.of(context);
    return app.findPhotoByPath(widget.imagePath)?.metadata ??
        app.pendingCaptureMetadata;
  }

  Future<PhotoEvaluation> _ensureEvaluation({bool force = false}) async {
    final cached = _evaluation;
    if (!force && cached != null && cached.score > 0) {
      return cached;
    }

    setState(() {
      _showAnalysis = true;
      _evaluating = true;
      if (force) {
        _evaluation = null;
      }
    });

    final app = XAestheticScope.of(context);
    final existingPhoto = app.findPhotoByPath(widget.imagePath);
    final metadata = existingPhoto?.metadata ?? app.pendingCaptureMetadata;
    final evaluation =
        await _evaluator.evaluate(widget.imagePath, metadata: metadata);

    if (!mounted) {
      return evaluation;
    }
    setState(() {
      _evaluation = evaluation;
      _evaluating = false;
    });

    if (existingPhoto != null) {
      await app.updatePhotoEvaluation(existingPhoto, evaluation);
    }
    return evaluation;
  }

  Future<void> _showEvaluation({bool force = false}) async {
    await _ensureEvaluation(force: force);
  }

  Future<void> _saveToLibrary() async {
    if (_saving || _saved) {
      return;
    }
    setState(() => _saving = true);
    final app = XAestheticScope.of(context);
    final evaluation = await _ensureEvaluation();
    final photo = await app.saveCurrentCaptureToLibrary(evaluation: evaluation);
    if (!mounted) {
      return;
    }
    setState(() {
      _saved = photo != null;
      _saving = false;
    });
    AppSnack.show(
        context,
        photo == null
            ? 'Không có ảnh để lưu.'
            : 'Đã lưu ảnh vào thư viện X-Aesthetic.');
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _currentMetadata();

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(widget.imagePath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Colors.black,
              child: Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 56)),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.60),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.72),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    _GlassButton(
                        icon: Icons.close_rounded, onTap: widget.onClose),
                    const Expanded(
                        child: Center(child: XBrandText(fontSize: 20))),
                    _GlassButton(
                      icon: Icons.info_outline_rounded,
                      onTap: () => AppSnack.show(context,
                          'Ảnh và đánh giá được lưu trong thư viện riêng của ứng dụng.'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _showAnalysis
                    ? _AnalysisOverlay(
                        key: const ValueKey('analysis'),
                        evaluation: _evaluation,
                        evaluating: _evaluating,
                        canSave: widget.canSave,
                        saved: _saved,
                        saving: _saving,
                        metadata: metadata,
                        onClose: () => setState(() => _showAnalysis = false),
                        onRetake: widget.onRetake,
                        onSave: _saveToLibrary,
                        onReevaluate: () => _showEvaluation(force: true),
                      )
                    : _ReviewActions(
                        key: const ValueKey('actions'),
                        canSave: widget.canSave,
                        saved: _saved,
                        saving: _saving,
                        metadata: metadata,
                        onRetake: widget.onRetake,
                        onSave: _saveToLibrary,
                        onShowAnalysis: () => _showEvaluation(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewActions extends StatelessWidget {
  final bool canSave;
  final bool saved;
  final bool saving;
  final CaptureMetadata? metadata;
  final VoidCallback onRetake;
  final VoidCallback onSave;
  final VoidCallback onShowAnalysis;

  const _ReviewActions({
    required this.canSave,
    required this.saved,
    required this.saving,
    required this.metadata,
    required this.onRetake,
    required this.onSave,
    required this.onShowAnalysis,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetadataChips(metadata: metadata),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (canSave) ...[
                _SoftActionButton(
                    label: 'Chụp lại',
                    icon: Icons.camera_alt_outlined,
                    onTap: onRetake),
                const SizedBox(width: 10),
                _SoftActionButton(
                  label: saving
                      ? 'Đang lưu'
                      : saved
                          ? 'Đã lưu'
                          : 'Lưu',
                  icon: saved ? Icons.check_rounded : Icons.save_alt_rounded,
                  onTap: onSave,
                ),
              ],
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onShowAnalysis,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: tokens.surface
                          .withValues(alpha: tokens.isDark ? 0.42 : 0.52),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 18,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_graph_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 7),
                        Text('Đánh giá',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalysisOverlay extends StatelessWidget {
  final PhotoEvaluation? evaluation;
  final bool evaluating;
  final bool canSave;
  final bool saved;
  final bool saving;
  final CaptureMetadata? metadata;
  final VoidCallback onClose;
  final VoidCallback onRetake;
  final VoidCallback onSave;
  final VoidCallback onReevaluate;

  const _AnalysisOverlay({
    required this.evaluation,
    required this.evaluating,
    required this.canSave,
    required this.saved,
    required this.saving,
    required this.metadata,
    required this.onClose,
    required this.onRetake,
    required this.onSave,
    required this.onReevaluate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    final result = evaluation;
    final metrics = result?.metrics ?? const <String, double>{};
    final suggestions = result?.suggestions ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: XCard(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        color: tokens.surface.withValues(alpha: tokens.isDark ? 0.92 : 0.95),
        child: evaluating && result == null
            ? SizedBox(
                height: 230,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: tokens.primary),
                      const SizedBox(height: 16),
                      Text('Đang phân tích ảnh...',
                          style: TextStyle(
                              color: tokens.text, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                                color: tokens.muted.withValues(alpha: 0.30),
                                borderRadius: BorderRadius.circular(999)))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: Text('Đánh giá ảnh',
                                style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900))),
                        TextButton.icon(
                          onPressed: evaluating ? null : onReevaluate,
                          icon: Icon(Icons.refresh_rounded,
                              size: 18, color: tokens.primary),
                          label: Text('Đánh giá lại',
                              style: TextStyle(
                                  color: tokens.primary,
                                  fontWeight: FontWeight.w900)),
                        ),
                        IconButton(
                            tooltip: 'Đóng đánh giá',
                            onPressed: onClose,
                            icon:
                                Icon(Icons.close_rounded, color: tokens.muted)),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text((result?.score ?? 0).toStringAsFixed(1),
                            style: TextStyle(
                                color: tokens.primary,
                                fontSize: 46,
                                fontWeight: FontWeight.w900,
                                height: 1)),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                                color: tokens.primarySoft,
                                borderRadius: BorderRadius.circular(999)),
                            child: Text(result?.verdict ?? 'Đang đánh giá',
                                style: TextStyle(
                                    color: tokens.primary,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      result == null
                          ? 'Đánh giá bằng xử lý ảnh cục bộ'
                          : 'Hồ sơ: ${result.contextAnalysis.resolvedContext.label} • ${result.contextAnalysis.isManual ? 'chọn thủ công' : 'suy luận tạm thời'}',
                      style: TextStyle(
                          color: tokens.muted, fontWeight: FontWeight.w700),
                    ),
                    if (result != null &&
                        result.contextAnalysis.evidence.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.contextAnalysis.evidence.first,
                        style: TextStyle(
                            color: tokens.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.25),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _MetadataChips(metadata: metadata),
                    const SizedBox(height: 16),
                    ..._metricRows(metrics, tokens.primary),
                    const SizedBox(height: 14),
                    XCard(
                      padding: const EdgeInsets.all(14),
                      radius: 18,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              color: tokens.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              suggestions.isEmpty
                                  ? 'Ảnh ổn. Hãy thử luyện bố cục chủ thể ở bước AI tiếp theo.'
                                  : suggestions.join('\n'),
                              style: TextStyle(
                                  color: tokens.text,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canSave) ...[
                      const SizedBox(height: 14),
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
                                  label: saving
                                      ? 'Đang lưu'
                                      : saved
                                          ? 'Đã lưu'
                                          : 'Lưu ảnh',
                                  icon: saved
                                      ? Icons.check_rounded
                                      : Icons.save_alt_rounded,
                                  onPressed: saving || saved ? null : onSave)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _metricRows(Map<String, double> metrics, Color color) {
    final entries = metrics.entries.toList();
    if (entries.isEmpty) {
      return const <Widget>[];
    }
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: _metricEntry(entries[i], color)),
            if (i + 1 < entries.length) ...[
              const SizedBox(width: 8),
              Expanded(child: _metricEntry(entries[i + 1], color)),
            ] else ...[
              const SizedBox(width: 8),
              const Expanded(child: SizedBox.shrink()),
            ],
          ],
        ),
      );
      if (i + 2 < entries.length) {
        rows.add(const SizedBox(height: 8));
      }
    }
    return rows;
  }

  Widget _metricEntry(MapEntry<String, double> entry, Color color) {
    final value = entry.value;
    return MetricTile(
      icon: _iconForMetric(entry.key),
      title: entry.key,
      value: value.toStringAsFixed(1),
      subtitle: value >= 7.2
          ? 'Tốt'
          : value >= 6.2
              ? 'Ổn'
              : 'Cần cải thiện',
      color: value < 6.2 ? XColors.orange : color,
    );
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
}

class _MetadataChips extends StatelessWidget {
  final CaptureMetadata? metadata;

  const _MetadataChips({required this.metadata});

  @override
  Widget build(BuildContext context) {
    final data = metadata;
    if (data == null) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetadataChip(
            icon: Icons.auto_awesome_mosaic_rounded,
            label: photoContextFromName(data.photoContext).shortLabel),
        _MetadataChip(
            icon: Icons.auto_awesome_rounded, label: _hdrLabel(data.hdrMode)),
        _MetadataChip(
            icon: Icons.aspect_ratio_rounded,
            label: _aspectLabel(data.aspectRatio)),
        _MetadataChip(
            icon: Icons.hd_rounded, label: _resolutionLabel(data.resolution)),
        _MetadataChip(
            icon: Icons.camera_rear_rounded,
            label: data.cameraLens == 'front' ? 'Camera trước' : 'Camera sau'),
      ],
    );
  }

  String _hdrLabel(String value) {
    switch (value) {
      case 'off':
        return 'HDR tắt';
      case 'light':
        return 'HDR Nhẹ';
      case 'strong':
        return 'HDR Mạnh';
      case 'hardware':
        return 'HDR+';
      default:
        return value;
    }
  }

  String _aspectLabel(String value) {
    switch (value) {
      case 'ratio34':
        return '3:4';
      case 'ratio916':
        return '9:16';
      case 'square':
        return '1:1';
      case 'full':
        return 'Full';
      default:
        return value;
    }
  }

  String _resolutionLabel(String value) {
    switch (value) {
      case 'low':
        return 'Thấp';
      case 'medium':
        return 'Trung bình';
      case 'high':
        return 'Cao';
      case 'veryHigh':
        return 'Rất cao';
      case 'ultraHigh':
        return 'Tối đa';
      case 'max':
        return 'Tối đa';
      default:
        return value;
    }
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _SoftActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SoftActionButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
