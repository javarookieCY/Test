import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// 右邊那頁：功能待定，先放「coming soon!」。
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ElementColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 64, color: ElementColors.accent),
            const SizedBox(height: 16),
            Text(
              'coming soon!',
              style: TextStyle(
                color: ElementColors.lightUi,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
