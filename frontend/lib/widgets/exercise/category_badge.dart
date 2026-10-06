import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/exercise_task.dart';
import '../../utils/constants.dart';

/// 分類的代表色：重訓藍、有氧橘、伸展綠
Color categoryColor(ExerciseTaskCategory c) => switch (c) {
      ExerciseTaskCategory.strength => ElementColors.accent,
      ExerciseTaskCategory.cardio => ElementColors.cardio,
      ExerciseTaskCategory.flexibility => ElementColors.flexibility,
    };

IconData categoryIcon(ExerciseTaskCategory c) => switch (c) {
      ExerciseTaskCategory.strength => Icons.fitness_center,
      ExerciseTaskCategory.cardio => CupertinoIcons.heart_fill,
      ExerciseTaskCategory.flexibility => Icons.self_improvement,
    };

/// 清單上的分類小膠囊，例如「重訓」
class CategoryBadge extends StatelessWidget {
  const CategoryBadge(this.category, {super.key});
  final ExerciseTaskCategory category;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(category.label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

/// iOS 設定頁風格的圓角方塊圖示，放在 CupertinoListTile 的 leading
class CategoryIconTile extends StatelessWidget {
  const CategoryIconTile(this.category, {super.key});
  final ExerciseTaskCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: categoryColor(category),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(categoryIcon(category), color: Colors.white, size: 17),
    );
  }
}
