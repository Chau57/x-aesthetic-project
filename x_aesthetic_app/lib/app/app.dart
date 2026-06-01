import 'package:flutter/material.dart';
import 'package:x_aesthetic_app/domain/entities/camera_enums.dart';
import 'package:x_aesthetic_app/domain/entities/photo_history_item.dart';
import 'package:x_aesthetic_app/presentation/theme/app_theme.dart';
import 'package:x_aesthetic_app/presentation/widgets/app_bottom_nav.dart';
import 'package:x_aesthetic_app/presentation/screens/home_screen.dart';
import 'package:x_aesthetic_app/presentation/screens/camera_screen.dart';
import 'package:x_aesthetic_app/presentation/screens/library_screen.dart';
import 'package:x_aesthetic_app/presentation/screens/progress_screen.dart';


class XAestheticApp extends StatelessWidget {
  const XAestheticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'X-Aesthetic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const XAestheticAppShell(),
    );
  }
}

class XAestheticAppShell extends StatefulWidget {
  const XAestheticAppShell({super.key});

  @override
  State<XAestheticAppShell> createState() => _XAestheticAppShellState();
}

class _XAestheticAppShellState extends State<XAestheticAppShell> {
  int _selectedIndex = 0; // Starts at HomeScreen (Trang chủ) as requested
  final List<PhotoHistoryItem> _history = [];

  void _savePhoto(PhotoHistoryItem item) {
    setState(() {
      _history.add(item);
      _selectedIndex =
          3; // Shift to Progress tab so they can review their trending chart updates
    });
  }

  void _navigateToCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          mode: CameraMode.normal,
          history: _history,
          onSavePhoto: _savePhoto,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      // Tab 0: Trang chủ (HomeScreen)
      HomeScreen(
        history: _history,
        onOpenCamera: _navigateToCamera,
        onSavePhoto: _savePhoto,
      ),

      // Tab 1: Dummy Placeholder (Camera is opened full-screen)
      const SizedBox.shrink(),

      // Tab 2: Thư viện (LibraryScreen)
      LibraryScreen(
        history: _history,
        onNavigateToCamera: _navigateToCamera,
      ),

      // Tab 3: Tiến bộ (ProgressScreen)
      ProgressScreen(
        history: _history,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 1) {
            _navigateToCamera();
          } else {
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }
}
