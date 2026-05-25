import 'package:flutter/material.dart';

class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post-capture Diagnosis')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Preview module placeholder. Later tasks will render aesthetic score, '
            'attribute deltas, Grad-CAM heatmap, and XAI guidance messages.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
