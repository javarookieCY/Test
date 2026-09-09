import 'package:flutter_application_1/utils/nutrition_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mifflinStJeorBmr', () {
    test('男性範例 (80kg / 180cm / 30歲)', () {
      // 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
      final bmr = mifflinStJeorBmr(
        sex: Sex.male,
        weightKg: 80,
        heightCm: 180,
        age: 30,
      );
      expect(bmr, closeTo(1780, 0.001));
    });

    test('女性範例 (60kg / 165cm / 28歲)', () {
      // 10*60 + 6.25*165 - 5*28 - 161 = 600 + 1031.25 - 140 - 161 = 1330.25
      final bmr = mifflinStJeorBmr(
        sex: Sex.female,
        weightKg: 60,
        heightCm: 165,
        age: 28,
      );
      expect(bmr, closeTo(1330.25, 0.001));
    });
  });

  group('computeTargets', () {
    test('維持目標：熱量 = TDEE，蛋白質 1.8 g/kg', () {
      final t = computeTargets(
        sex: Sex.male,
        weightKg: 80,
        heightCm: 180,
        age: 30,
        activity: ActivityLevel.moderate, // ×1.50（僅日常活動，不含運動）
        goal: Goal.maintain,
      );
      // BMR 1780 → TDEE 1780*1.50 = 2670
      expect(t.tdee, closeTo(2670, 0.001));
      expect(t.calories, 2670); // 維持 ×1.0
      expect(t.proteinG, (1.8 * 80).round()); // 144
    });

    test('減脂目標：熱量打 85 折，蛋白質提高到 2.2 g/kg', () {
      final t = computeTargets(
        sex: Sex.male,
        weightKg: 80,
        heightCm: 180,
        age: 30,
        activity: ActivityLevel.moderate,
        goal: Goal.cut,
      );
      expect(t.calories, (2670 * 0.85).round()); // 2270
      expect(t.proteinG, (2.2 * 80).round()); // 176
    });

    test('活動係數只反映日常活動，明顯低於傳統含運動的 Mifflin 值', () {
      expect(ActivityLevel.light.factor, lessThan(1.375));
      expect(ActivityLevel.moderate.factor, lessThan(1.55));
      expect(ActivityLevel.active.factor, lessThan(1.725));
    });

    test('三大營養素熱量加總 ≈ 目標熱量（誤差在四捨五入範圍內）', () {
      final t = computeTargets(
        sex: Sex.female,
        weightKg: 60,
        heightCm: 165,
        age: 28,
        activity: ActivityLevel.light,
        goal: Goal.maintain,
      );
      final macroKcal = t.proteinG * 4 + t.carbsG * 4 + t.fatG * 9;
      expect((macroKcal - t.calories).abs(), lessThanOrEqualTo(10));
    });

    test('脂肪至少達 0.8 g/kg 或 25% 熱量（取高者）', () {
      final t = computeTargets(
        sex: Sex.male,
        weightKg: 100,
        heightCm: 175,
        age: 40,
        activity: ActivityLevel.sedentary,
        goal: Goal.cut,
      );
      expect(t.fatG, greaterThanOrEqualTo((0.8 * 100).round()));
    });

    test('carbs 不會是負數（極端：低熱量高蛋白）', () {
      final t = computeTargets(
        sex: Sex.female,
        weightKg: 45,
        heightCm: 150,
        age: 65,
        activity: ActivityLevel.sedentary,
        goal: Goal.cut,
      );
      expect(t.carbsG, greaterThanOrEqualTo(0));
    });
  });
}
