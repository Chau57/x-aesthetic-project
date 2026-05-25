import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learning Dashboard')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Dashboard placeholder. Later tasks will connect Hive logs, recurring '
            'mistake statistics, and personalized learning roadmap charts.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
