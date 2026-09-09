import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/nutrition_math.dart';

/// 首頁的「每日目標」卡片：剩餘熱量、攝取進度條、三大營養素目標。
/// 目標數字來自使用者個人資料試算（Mifflin-St Jeor → TDEE → 依目標調整）。
class DailyTargetCard extends StatelessWidget {
  const DailyTargetCard({
    super.key,
    required this.targets,
    required this.consumed,
    this.burned = 0,
    this.onEditProfile,
  });

  final NutritionTargets targets;
  final int consumed; // 今日已攝取熱量
  final int burned; // 今日運動消耗熱量
  final VoidCallback? onEditProfile;

  // 有效預算 = 目標 + 運動消耗；剩餘 = 有效預算 − 已攝取
  int get _effectiveBudget => targets.calories + burned;
  int get _remaining => _effectiveBudget - consumed;

  @override
  Widget build(BuildContext context) {
    final progress = _effectiveBudget <= 0
        ? 0.0
        : (consumed / _effectiveBudget).clamp(0.0, 1.0);
    final over = _remaining < 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ElementColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('每日目標',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                if (onEditProfile != null)
                  InkWell(
                    onTap: onEditProfile,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune, size: 14, color: Colors.white54),
                        SizedBox(width: 4),
                        Text('調整', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${over ? 0 : _remaining}',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Text(over ? 'kcal（已超標 ${-_remaining}）' : 'kcal 剩餘',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(
                  over ? Colors.redAccent : ElementColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              burned > 0
                  ? '已攝取 $consumed / $_effectiveBudget kcal'
                    '（目標 ${targets.calories} + 運動 $burned）'
                  : '已攝取 $consumed / ${targets.calories} kcal',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Divider(height: 24, color: Colors.white12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Macro(label: '蛋白質', grams: targets.proteinG),
                _Macro(label: '碳水', grams: targets.carbsG),
                _Macro(label: '脂肪', grams: targets.fatG),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.grams});
  final String label;
  final int grams;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$grams g',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
