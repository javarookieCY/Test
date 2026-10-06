import 'package:flutter_application_1/models/exercise_task.dart';
import 'package:flutter_application_1/utils/exercise_catalog.dart';
import 'package:flutter_application_1/utils/exercise_guides.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('動作庫資料', () {
    test('名稱不重複（存進 DB 的就是名稱）', () {
      final names = kExerciseCatalog.map((e) => e.name).toList();
      expect(names.toSet().length, names.length);
    });

    test('每個動作的範圍合理：重訓 ≤ 8 組、有氧 ≤ 300 分、伸展 ≤ 90 分，預設值在範圍內', () {
      for (final e in kExerciseCatalog) {
        expect(e.minAmount, greaterThanOrEqualTo(1), reason: e.name);
        expect(e.minAmount, lessThan(e.maxAmount), reason: e.name);
        expect((e.maxAmount - e.minAmount) % e.step, 0, reason: '${e.name} 上限沒對齊 step');
        expect(e.isValidAmount(e.defaultAmount), isTrue, reason: e.name);
        final cap = switch (e.category) {
          ExerciseTaskCategory.strength => 8,
          ExerciseTaskCategory.cardio => 300,
          ExerciseTaskCategory.flexibility => 90,
        };
        expect(e.maxAmount, lessThanOrEqualTo(cap), reason: e.name);
      }
    });

    test('重訓一定有部位與器材，有氧 / 伸展沒有', () {
      for (final e in kExerciseCatalog) {
        final strength = e.category == ExerciseTaskCategory.strength;
        expect(e.bodyPart != null, strength, reason: e.name);
        expect(e.equipment != null, strength, reason: e.name);
      }
    });

    test('三種分類、六個部位都有動作可選', () {
      for (final c in ExerciseTaskCategory.values) {
        expect(kExerciseCatalog.where((e) => e.category == c), isNotEmpty, reason: c.label);
      }
      for (final p in BodyPart.values) {
        expect(kExerciseCatalog.where((e) => e.bodyPart == p), isNotEmpty, reason: p.label);
      }
    });
  });

  group('份量範圍', () {
    final squat = findExercise('高腳杯深蹲')!;
    final walk = findExercise('快走')!;

    test('888 組深蹲、0 組、負數都不合法', () {
      expect(squat.isValidAmount(888), isFalse);
      expect(squat.isValidAmount(0), isFalse);
      expect(squat.isValidAmount(-3), isFalse);
      expect(squat.isValidAmount(3), isTrue);
    });

    test('有氧以 5 分鐘為單位，不在刻度上的不合法', () {
      expect(walk.isValidAmount(30), isTrue);
      expect(walk.isValidAmount(33), isFalse);
      expect(walk.isValidAmount(5), isFalse); // 快走最少 10 分鐘
    });

    test('滾輪選項就是 min..max 每 step 一格，不會出現範圍外的數字', () {
      expect(squat.amountOptions, [1, 2, 3, 4, 5, 6]);
      expect(walk.amountOptions.first, 10);
      expect(walk.amountOptions.last, 120);
      expect(walk.amountOptions.every(walk.isValidAmount), isTrue);
    });

    test('clampAmount 把任意數字拉回範圍並對齊刻度', () {
      expect(squat.clampAmount(888), 6);
      expect(squat.clampAmount(0), 1);
      expect(walk.clampAmount(33), 35);
      expect(walk.clampAmount(999), 120);
      expect(findExercise('划船機')!.clampAmount(62), 60);
    });
  });

  group('查詢', () {
    test('findExercise：舊版自己取名的動作找不到', () {
      expect(findExercise('棒式')?.timed, isTrue);
      expect(findExercise('超級無敵深蹲'), isNull);
    });

    test('searchCatalog 只回傳該分類，可用中文、英文（不分大小寫）、部位、器材搜尋', () {
      expect(
          searchCatalog('深蹲', ExerciseTaskCategory.strength).map((e) => e.name),
          containsAll(['徒手深蹲', '高腳杯深蹲', '槓鈴深蹲']));
      expect(searchCatalog('squat', ExerciseTaskCategory.strength).map((e) => e.name),
          contains('保加利亞分腿蹲'));
      expect(searchCatalog('胸', ExerciseTaskCategory.strength).map((e) => e.name),
          contains('槓鈴臥推'));
      expect(searchCatalog('啞鈴', ExerciseTaskCategory.strength)
              .every((e) => e.equipment == Equipment.dumbbell),
          isTrue);
      expect(searchCatalog('深蹲', ExerciseTaskCategory.cardio), isEmpty);
      // 只給徒手：臥推都不會出現；有槓鈴才有槓鈴臥推；有氧不受器材影響
      expect(searchCatalog('臥推', ExerciseTaskCategory.strength,
          equipment: {Equipment.bodyweight}), isEmpty);
      expect(searchCatalog('臥推', ExerciseTaskCategory.strength,
              equipment: {Equipment.bodyweight, Equipment.barbell}).map((e) => e.name),
          ['槓鈴臥推']);
      expect(searchCatalog('', ExerciseTaskCategory.cardio, equipment: {}).length,
          searchCatalog('', ExerciseTaskCategory.cardio).length);
      expect(searchCatalog('', ExerciseTaskCategory.flexibility).length,
          kExerciseCatalog.where((e) => e.category == ExerciseTaskCategory.flexibility).length);
    });
  });

  group('動作說明', () {
    test('動作庫每個動作都有說明（部位、至少 2 個步驟、至少 1 個注意事項）', () {
      for (final e in kExerciseCatalog) {
        final g = kExerciseGuides[e.name];
        expect(g, isNotNull, reason: '${e.name} 沒有說明');
        expect(g!.muscles, isNotEmpty, reason: e.name);
        expect(g.steps.length, greaterThanOrEqualTo(2), reason: e.name);
        expect(g.tips, isNotEmpty, reason: e.name);
      }
    });

    test('說明裡沒有動作庫以外的名稱（避免改名後留下孤兒說明）', () {
      final names = kExerciseCatalog.map((e) => e.name).toSet();
      expect(kExerciseGuides.keys.where((k) => !names.contains(k)), isEmpty);
    });
  });

  group('訓練清單消耗熱量', () {
    ExerciseTask t(String name, {int? sets, int? minutes}) => ExerciseTask(
        date: '2026-10-7',
        category: findExercise(name)?.category ?? ExerciseTaskCategory.strength,
        name: name,
        sets: sets,
        minutes: minutes);

    test('重訓每組算 2 分鐘：深蹲 3 組 = 6 分鐘 × MET 5 × 70kg ≈ 35 kcal', () {
      expect(taskMinutes(t('高腳杯深蹲', sets: 3)), 6);
      expect(estimateTaskKcal(t('高腳杯深蹲', sets: 3), weightKg: 70), 35);
    });

    test('有氧依分鐘與 MET：慢跑 30 分 × 7.0 × 70kg = 245 kcal，比快走多', () {
      final jog = estimateTaskKcal(t('慢跑', minutes: 30), weightKg: 70);
      final walk = estimateTaskKcal(t('快走', minutes: 30), weightKg: 70);
      expect(jog, 245);
      expect(jog, greaterThan(walk));
    });

    test('不在動作庫的動作算 0', () {
      expect(estimateTaskKcal(t('不存在的動作', sets: 3)), 0);
    });

    test('每個動作都有合理的 MET（1.5–15）', () {
      for (final e in kExerciseCatalog) {
        expect(e.met, inInclusiveRange(1.5, 15), reason: e.name);
      }
    });
  });
}
