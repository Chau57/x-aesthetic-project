import 'package:flutter/material.dart';

import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/photo_context.dart';
import '../shared/x_theme.dart';
import '../shared/x_widgets.dart';

class GalleryScreen extends StatelessWidget {
  final VoidCallback onStartCapture;
  final ValueChanged<String> onOpenPhoto;

  const GalleryScreen(
      {required this.onStartCapture, required this.onOpenPhoto, super.key});

  @override
  Widget build(BuildContext context) {
    return XScopeBuilder(
      builder: (context, app) {
        final photos = app.photos;
        return XBackground(
          child: SafeArea(
            child: Column(
              children: [
                const _SimpleHeader(title: 'Thư viện'),
                Expanded(
                  child: photos.isEmpty
                      ? EmptyState(
                          icon: Icons.photo_library_outlined,
                          title: 'Thư viện ứng dụng đang trống',
                          subtitle:
                              'Ảnh chụp sẽ được lưu trong thư mục riêng của X-Aesthetic, không ghi thẳng vào thư viện ảnh của máy.',
                          actionLabel: 'Chụp ảnh đầu tiên',
                          onAction: onStartCapture,
                        )
                      : RefreshIndicator(
                          onRefresh: app.refreshLibrary,
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(18, 4, 18, 122),
                            itemCount: photos.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.78,
                            ),
                            itemBuilder: (context, index) {
                              final photo = photos[index];
                              return _GalleryCard(
                                photo: photo,
                                onDelete: () async {
                                  final confirmed =
                                      await _confirmDelete(context);
                                  if (!confirmed) {
                                    return;
                                  }
                                  await app.deletePhoto(photo);
                                  if (context.mounted) {
                                    AppSnack.show(context,
                                        'Đã xóa ảnh khỏi thư viện ứng dụng.');
                                  }
                                },
                                onOpen: () => onOpenPhoto(photo.filePath),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final tokens = context.x;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Xóa ảnh?',
            style: TextStyle(color: tokens.text, fontWeight: FontWeight.w900)),
        content: Text(
          'Ảnh sẽ bị xóa khỏi thư viện riêng của X-Aesthetic. Thao tác này không ảnh hưởng thư viện ảnh hệ thống.',
          style: TextStyle(color: tokens.muted, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy')),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Xóa'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

class _SimpleHeader extends StatelessWidget {
  final String title;

  const _SimpleHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Center(
        child: Text(title,
            style: TextStyle(
                color: tokens.text, fontSize: 22, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final CapturedPhoto photo;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _GalleryCard(
      {required this.photo, required this.onDelete, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return XCard(
      padding: const EdgeInsets.all(8),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PhotoThumbnail(photo: photo, scoreSize: 13),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14)),
                        ),
                        child: const Text('Xem',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(photo.verdict,
                        style: TextStyle(
                            color: tokens.text, fontWeight: FontWeight.w900)),
                    Text(_formatDate(photo.createdAt),
                        style: TextStyle(
                            color: tokens.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_formatMetadata(photo),
                        style: TextStyle(
                            color: tokens.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Xóa khỏi thư viện ứng dụng',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: tokens.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month • $hour:$minute';
  }

  String _formatMetadata(CapturedPhoto photo) {
    final hdr =
        photo.metadata.hdrMode == 'hardware' ? 'HDR+' : photo.metadata.hdrMode;
    final lens = photo.metadata.cameraLens == 'front' ? 'Trước' : 'Sau';
    final ratio = _aspectLabel(photo.metadata.aspectRatio);
    final context = photo.hasEvaluation
        ? photo.evaluation.contextAnalysis.resolvedContext.shortLabel
        : photoContextFromName(photo.metadata.photoContext).shortLabel;
    return '$context • $lens • $ratio • ${photo.metadata.resolution} • $hdr';
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
}
