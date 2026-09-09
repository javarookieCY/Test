import 'package:flutter_application_1/utils/exercise_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('運動強度分級', () {
    test('每個預設至少兩檔強度、MET 遞增', () {
      for (final p in kExercisePresets) {
        expect(p.intensities.length, greaterThanOrEqualTo(2), reason: p.name);
        for (var i = 1; i < p.intensities.length; i++) {
          expect(p.intensities[i].met,
              greaterThan(p.intensities[i - 1].met),
              reason: '${p.name} 第 $i 檔');
        }
      }
    });

    test('跑步：五分速比七分速估出更高熱量', () {
      final run = kExercisePresets.firstWhere((p) => p.name == '跑步');
      final easy = run.intensities.first; // 7:00/km
      final fast = run.intensities[2]; // 5:00/km
      final easyKcal =
          estimateExerciseKcal(met: easy.met, minutes: 30, weightKg: 70);
      final fastKcal =
          estimateExerciseKcal(met: fast.met, minutes: 30, weightKg: 70);
      expect(fastKcal, greaterThan(easyKcal));
      // 差距應該有感（至少 20%）
      expect(fastKcal / easyKcal, greaterThan(1.2));
    });

    test('estimateExerciseKcal 缺體重時用 60kg', () {
      expect(estimateExerciseKcal(met: 10, minutes: 60),
          estimateExerciseKcal(met: 10, minutes: 60, weightKg: 60));
    });
  });
}
