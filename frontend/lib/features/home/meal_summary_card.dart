import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import 'home_panel.dart';

class MealSummaryCard extends StatelessWidget {
  const MealSummaryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.calories,
    required this.itemCount,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final int calories;
  final int itemCount;
  final VoidCallback onTap;

  static const double _width = 150;

  @override
  Widget build(BuildContext context) {
    String detail = '$calories kcal';
    Color iconColor = Colors.grey;
    if (itemCount > 0) {
      detail = '$calories kcal・$itemCount 樣';
      iconColor = ElementColors.calorieRing;
    }

    return SizedBox(
      width: _width,
      child: HomePanel(
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
