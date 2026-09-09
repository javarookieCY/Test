import 'dart:math' as math;

// ── 個人化營養目標的純計算邏輯 ──────────────────────────────
// 這個檔案沒有任何 Flutter / DB 依賴，方便單獨寫測試。
// 流程：基本資料 → BMR(基礎代謝) → TDEE(每日總消耗) → 依目標調整熱量 → 拆成三大營養素。
//
// 重要：這裡的「活動量」只代表『非運動的日常活動 (NEAT)』——工作型態、通勤、走動，
// 不包含刻意的運動。刻意運動由運動頁單獨記錄，消耗熱量再加回首頁的剩餘熱量，
// 這樣才不會被重複計算一次。

enum Sex { male, female }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum Goal { cut, maintain, bulk }

extension ActivityLevelInfo on ActivityLevel {
  /// TDEE = BMR × 這個係數。
  /// 因為運動另外記錄、另外加回，這裡的係數只反映『日常非運動活動』，
  /// 比傳統含運動的 Mifflin 係數略低。
  double get factor => switch (this) {
        ActivityLevel.sedentary => 1.20,
        ActivityLevel.light => 1.35,
        ActivityLevel.moderate => 1.50,
        ActivityLevel.active => 1.70,
        ActivityLevel.veryActive => 1.90,
      };

  String get label => switch (this) {
        ActivityLevel.sedentary => '久坐（辦公桌工作，多數時間坐著）',
        ActivityLevel.light => '輕度（常需走動的工作或通勤）',
        ActivityLevel.moderate => '中度（工作以站立、走動為主）',
        ActivityLevel.active => '高度（體力勞動工作）',
        ActivityLevel.veryActive => '非常高（重度體力勞動）',
      };
}

extension GoalInfo on Goal {
  /// 目標熱量 = TDEE × 這個係數（百分比法：減脂 −15%、維持 ±0、增肌 +10%）
  double get calorieFactor => switch (this) {
        Goal.cut => 0.85,
        Goal.maintain => 1.0,
        Goal.bulk => 1.10,
      };

  /// 蛋白質目標（每公斤體重克數），依目標略為不同
  double get proteinPerKg => switch (this) {
        Goal.cut => 2.2, // 減脂時提高蛋白質以保留肌肉
        Goal.maintain => 1.8,
        Goal.bulk => 2.0,
      };

  String get label => switch (this) {
        Goal.cut => '減脂',
        Goal.maintain => '維持',
        Goal.bulk => '增肌',
      };
}

/// 一組每日目標數字，畫面直接拿去顯示。
class NutritionTargets {
  const NutritionTargets({
    required this.bmr,
    required this.tdee,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double bmr; // kcal，基礎代謝
  final double tdee; // kcal，每日總消耗
  final int calories; // kcal，依目標調整後的每日攝取目標
  final int proteinG; // g
  final int carbsG; // g
  final int fatG; // g

  /// 三大營養素各佔目標熱量的百分比（顯示用）
  (int p, int c, int f) get macroPercent {
    if (calories <= 0) return (0, 0, 0);
    int pct(int grams, int kcalPerG) =>
        ((grams * kcalPerG) / calories * 100).round();
    return (pct(proteinG, 4), pct(carbsG, 4), pct(fatG, 9));
  }
}

/// Mifflin-St Jeor 公式算 BMR（基礎代謝率, kcal/日）。
double mifflinStJeorBmr({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return base + (sex == Sex.male ? 5 : -161);
}

/// 從基本資料一路算到三大營養素目標。
///
/// 拆分策略（以體重錨定，MacroFactor 式）：
///   1. 蛋白質 = 目標 × (1.6–2.2 g/kg)
///   2. 脂肪   = max(目標熱量的 25%, 0.8 g/kg) —— 取較高者，確保荷爾蒙所需脂肪
///   3. 碳水   = 剩下的熱量 ÷ 4
NutritionTargets computeTargets({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
  required ActivityLevel activity,
  required Goal goal,
}) {
  final bmr = mifflinStJeorBmr(
    sex: sex,
    weightKg: weightKg,
    heightCm: heightCm,
    age: age,
  );
  final tdee = bmr * activity.factor;
  final calories = (tdee * goal.calorieFactor).round();

  final proteinG = (goal.proteinPerKg * weightKg).round();

  final fatFromPercent = calories * 0.25 / 9;
  final fatFromBodyweight = 0.8 * weightKg;
  final fatG = math.max(fatFromPercent, fatFromBodyweight).round();

  final remainingKcal = calories - proteinG * 4 - fatG * 9;
  final carbsG = (remainingKcal / 4).round().clamp(0, 100000);

  return NutritionTargets(
    bmr: bmr,
    tdee: tdee,
    calories: calories,
    proteinG: proteinG,
    carbsG: carbsG,
    fatG: fatG,
  );
}
