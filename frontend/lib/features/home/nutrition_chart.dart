import 'package:flutter/material.dart';

import '../../utils/constants.dart';

/// 首頁的卡片：顯示今天還可以吃多少熱量、蛋白質。
/// 自己不讀資料庫，數字由 Home 算好傳進來。
class NutritionChart extends StatelessWidget {
  const NutritionChart({
    super.key,
    required this.remainingCalorie,
    required this.targetCalorie,
    required this.remainingProtein,
    required this.targetProtein,
  });

  final int remainingCalorie; // 剩餘熱量 (kcal)，可能是負的(吃超過)
  final int targetCalorie; // 目標熱量 (kcal)
  final int remainingProtein; // 剩餘蛋白質 (g)
  final int targetProtein; // 目標蛋白質 (g)

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ElementColors.panelBg,
      elevation: 0, // 不要陰影
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ElementColors.panelBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '今日剩餘',
              style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _NutrientRow(
              label: '熱量',
              remaining: remainingCalorie,
              target: targetCalorie,
              unit: 'kcal',
            ),
            const SizedBox(height: 12),
            _NutrientRow(
              label: '蛋白質',
              remaining: remainingProtein,
              target: targetProtein,
              unit: 'g',
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片裡的一列，例如：熱量          1350 kcal / 目標 2000
class _NutrientRow extends StatelessWidget {
  const _NutrientRow({
    required this.label,
    required this.remaining,
    required this.target,
    required this.unit,
  });

  final String label;
  final int remaining;
  final int target;
  final String unit;

  @override
  Widget build(BuildContext context) {
    // 還有剩：顯示剩多少；吃超過(負數)：顯示「超過 多少」
    String valueText;
    if (remaining >= 0) {
      valueText = '$remaining $unit';
    } else {
      final int over = -remaining;
      valueText = '超過 $over $unit';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              valueText,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              '目標 $target $unit',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
