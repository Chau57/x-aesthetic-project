import 'package:flutter/material.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Guidance')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Camera module placeholder. Task 1.2 will connect Camera Preview, '
            'YOLO context detection, PluginManager, and CustomPainter overlays.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
