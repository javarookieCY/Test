import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import 'calorie_gauge.dart';

class NutritionChart extends StatelessWidget {
  const NutritionChart({
    super.key,
    required this.remainingCalorie,
    required this.targetCalorie,
    required this.consumedCarbs,
    required this.targetCarbs,
    required this.consumedFat,
    required this.targetFat,
    required this.consumedProtein,
    required this.targetProtein,
    required this.onTap,
  });

  final int remainingCalorie;
  final int targetCalorie;
  final int consumedCarbs;
  final int targetCarbs;
  final int consumedFat;
  final int targetFat;
  final int consumedProtein;
  final int targetProtein;
  final VoidCallback onTap;

  static double _usedProgress(int remaining, int target) {
    if (target <= 0) {
      return 0;
    }

    final int used = target - remaining;
    double progress = used.toDouble() / target.toDouble();

    if (progress < 0) {
      progress = 0;
    }
    if (progress > 1) {
      progress = 1;
    }
    return progress;
  }

  @override
  Widget build(BuildContext context) {
    Color gaugeColor = ElementColors.calorieRing;
    Color numberColor = Colors.white;
    int number = remainingCalorie;
    String label = 'kcal 剩餘';
    if (remainingCalorie < 0) {
      gaugeColor = ElementColors.warning;
      numberColor = ElementColors.warning;
      number = -remainingCalorie;
      label = 'kcal 已超過';
    }

    final double progress = _usedProgress(remainingCalorie, targetCalorie);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CalorieGauge(
              progress: progress,
              color: gaugeColor,
              number: number,
              numberColor: numberColor,
              label: label,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _MacroBar(label: '碳水', consumed: consumedCarbs, target: targetCarbs, color: ElementColors.carbsBar),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MacroBar(label: '脂肪', consumed: consumedFat, target: targetFat, color: ElementColors.fatBar),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MacroBar(label: '蛋白質', consumed: consumedProtein, target: targetProtein, color: ElementColors.proteinBar),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
  });

  final String label;
  final int consumed;
  final int target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    double progress = 0;
    if (target > 0) {
      progress = consumed.toDouble() / target.toDouble();
    }
    if (progress > 1) {
      progress = 1;
    }

    Color barColor = color;
    Color valueColor = Colors.grey;
    if (consumed > target) {
      barColor = ElementColors.warning;
      valueColor = ElementColors.warning;
    }

    final String valueText = '$consumed/$target g';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: barColor,
            backgroundColor: color.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(height: 6),
        Text(valueText, style: TextStyle(color: valueColor, fontSize: 12)),
      ],
    );
  }
}
