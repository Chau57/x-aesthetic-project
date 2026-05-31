import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CameraControlBar extends StatefulWidget {
  final VoidCallback onGuideTap;
  final VoidCallback onShutterTap;
  final String? lastThumbnail;
  final double bottomOffset;
  final Widget? leftButtonOverride;
  final Widget? rightButtonOverride;

  const CameraControlBar({
    super.key,
    required this.onGuideTap,
    required this.onShutterTap,
    this.lastThumbnail,
    required this.bottomOffset,
    this.leftButtonOverride,
    this.rightButtonOverride,
  });

  @override
  State<CameraControlBar> createState() => _CameraControlBarState();
}

class _CameraControlBarState extends State<CameraControlBar> {
  bool _isShutterPressing = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: widget.bottomOffset,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. Left Control (Overlay Toggle or Custom Close Button)
            widget.leftButtonOverride ??
                GestureDetector(
                  onTap: widget.onGuideTap,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1.5),
                    ),
                    child: const Icon(
                      Icons.grid_on_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),

            // 2. Central Shutter Button
            GestureDetector(
              onTapDown: (_) => setState(() => _isShutterPressing = true),
              onTapUp: (_) => setState(() => _isShutterPressing = false),
              onTapCancel: () => setState(() => _isShutterPressing = false),
              onTap: widget.onShutterTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 78,
                height: 78,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: BoxDecoration(
                    color: _isShutterPressing
                        ? const Color(0xFF235331)
                        : AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),

            // 3. Right Control (Thumbnail Gallery or Custom Reference Thumbnail)
            widget.rightButtonOverride ??
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.lastThumbnail != null
                      ? Image.network(
                          widget.lastThumbnail!,
                          fit: BoxFit.cover,
                        )
                      : const Icon(
                          Icons.photo_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
          ],
        ),
      ),
    );
  }
}
