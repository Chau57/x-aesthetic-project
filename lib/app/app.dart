import 'package:flutter/material.dart';

import '../presentation/camera/camera_screen.dart';
import '../presentation/dashboard/dashboard_screen.dart';
import '../presentation/gallery/gallery_screen.dart';
import '../presentation/photo_review/photo_review_screen.dart';
import '../presentation/shared/x_theme.dart';
import 'x_aesthetic_controller.dart';

class XAestheticApp extends StatefulWidget {
  const XAestheticApp({super.key});

  @override
  State<XAestheticApp> createState() => _XAestheticAppState();
}

class _XAestheticAppState extends State<XAestheticApp> {
  late final XAestheticController _controller;

  @override
  void initState() {
    super.initState();
    _controller = XAestheticController();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return XAestheticScope(
      controller: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return MaterialApp(
            title: 'X-Aesthetic',
            debugShowCheckedModeBanner: false,
            theme: XAestheticTheme.lightTheme,
            darkTheme: XAestheticTheme.darkTheme,
            themeMode: _controller.themeMode,
            home: AppShell(controller: _controller),
          );
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  final XAestheticController controller;

  const AppShell({required this.controller, super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  String? _reviewImagePath;
  bool _reviewCanSave = false;

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      _reviewImagePath = null;
      _reviewCanSave = false;
    });
  }

  void _openCapturedPhoto(String imagePath) {
    setState(() {
      _reviewImagePath = imagePath;
      _reviewCanSave = true;
    });
  }

  void _openLibraryPhoto(String imagePath) {
    widget.controller.setCurrentCapture(imagePath);
    setState(() {
      _reviewImagePath = imagePath;
      _reviewCanSave = false;
    });
  }

  void _closeReview() {
    setState(() {
      _reviewImagePath = null;
      _reviewCanSave = false;
    });
  }

  void _retakeFromReview() {
    setState(() {
      _selectedIndex = 0;
      _reviewImagePath = null;
      _reviewCanSave = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCameraTab = _selectedIndex == 0;
    final isReviewing = _reviewImagePath != null;

    final screens = <Widget>[
      CameraScreen(
        onImageCaptured: _openCapturedPhoto,
        onOpenLatestPhoto: _openLibraryPhoto,
        onClose: () => _selectTab(1),
        isActive: isCameraTab && !isReviewing,
      ),
      GalleryScreen(
        onStartCapture: () => _selectTab(0),
        onOpenPhoto: _openLibraryPhoto,
      ),
      const DashboardScreen(),
    ];

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: screens),
          if (isReviewing)
            Positioned.fill(
              child: PhotoReviewScreen(
                imagePath: _reviewImagePath!,
                canSave: _reviewCanSave,
                onClose: _closeReview,
                onRetake: _retakeFromReview,
              ),
            ),
        ],
      ),
      bottomNavigationBar: isCameraTab || isReviewing
          ? null
          : XAestheticBottomNav(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectTab,
            ),
    );
  }
}

class XAestheticBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const XAestheticBottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    const items = [
      _NavItem(Icons.camera_alt_outlined, Icons.camera_alt_rounded, 'Chụp'),
      _NavItem(Icons.photo_library_outlined, Icons.photo_library_rounded,
          'Thư viện'),
      _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Tiến độ'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: tokens.surface.withValues(alpha: tokens.isDark ? 0.93 : 0.94),
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: tokens.border),
          boxShadow: [
            BoxShadow(
                color: tokens.shadow,
                blurRadius: 26,
                offset: const Offset(0, 12))
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _BottomNavButton(
                  item: items[i],
                  selected: selectedIndex == i,
                  onTap: () => onDestinationSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem(this.icon, this.selectedIcon, this.label);
}

class _BottomNavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavButton(
      {required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.x;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? tokens.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? item.selectedIcon : item.icon,
                color: selected ? tokens.primary : tokens.muted, size: 23),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? tokens.primary : tokens.muted,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 11.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
