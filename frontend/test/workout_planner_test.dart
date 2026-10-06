import 'package:flutter_application_1/models/exercise_task.dart';
import 'package:flutter_application_1/utils/exercise_catalog.dart';
import 'package:flutter_application_1/utils/nutrition_math.dart';
import 'package:flutter_application_1/utils/workout_planner.dart';
import 'package:flutter_test/flutter_test.dart';

WeeklyPlan plan({
  Goal goal = Goal.maintain,
  int days = 3,
  int age = 25,
  double weight = 70,
  double height = 175,
  Set<Equipment> equipment = const {Equipment.dumbbell},
  Set<int>? weekdays,
}) =>
    buildWeeklyPlan(
        goal: goal,
        workoutWeekdays: weekdays ?? defaultWorkoutWeekdays(days),
        age: age,
        weightKg: weight,
        heightCm: height,
        equipment: equipment);

const _bodyweightOnly = <Equipment>{};
const _gym = {Equipment.dumbbell, Equipment.barbell, Equipment.machine};

Iterable<PlannedExercise> allItems(WeeklyPlan p) => p.days.expand((d) => d.items);

void main() {
  group('buildWeeklyPlan', () {
    test('永遠回傳 7 天，選的那幾天運動、其他天休息（1–6 天都可以）', () {
      for (final goal in Goal.values) {
        for (int n = 1; n <= kMaxWorkoutDays; n++) {
          final chosen = defaultWorkoutWeekdays(n);
          final p = plan(goal: goal, weekdays: chosen);
          expect(p.days.length, 7);
          expect(p.trainingDays, n);
          for (int d = 1; d <= 7; d++) {
            expect(p.days[d - 1].type != DayType.rest, chosen.contains(d),
                reason: '$goal $n 天，週$d');
          }
        }
      }
    });

    test('自己挑的日子：週二、四、六運動', () {
      final p = plan(goal: Goal.bulk, weekdays: {2, 4, 6});
      expect(p.days.map((d) => d.type), [
        DayType.rest, DayType.fullBody, DayType.rest, DayType.fullBody,
        DayType.rest, DayType.fullBody, DayType.rest,
      ]);
    });

    test('選 7 天會被限制在 6 天（至少留一天休息）；不合法的日子忽略', () {
      expect(plan(weekdays: {1, 2, 3, 4, 5, 6, 7}).trainingDays, 6);
      expect(plan(weekdays: {0, 8, 3}).trainingDays, 1);
      expect(plan(weekdays: {}).trainingDays, 1);
    });

    test('預設運動日把休息分散開', () {
      expect(defaultWorkoutWeekdays(3), {1, 3, 5});
      expect(defaultWorkoutWeekdays(4), {1, 2, 4, 5});
      expect(defaultWorkoutWeekdays(9), hasLength(kMaxWorkoutDays));
    });

    test('各種身體狀況 × 器材組合：動作都在動作庫、器材都有、份量合理、同一天不重複', () {
      for (final goal in Goal.values) {
        for (final days in [3, 4, 5]) {
          for (final age in [20, 55, 70]) {
            for (final weight in [45.0, 70.0, 110.0]) {
              for (final eq in [_bodyweightOnly, {Equipment.dumbbell}, {Equipment.barbell}, _gym]) {
                final p = plan(goal: goal, days: days, age: age, weight: weight, equipment: eq);
                for (final day in p.days) {
                  final names = day.items.map((e) => e.name).toList();
                  expect(names.where((n) => n != '快走' && n != '慢跑').toSet().length,
                      names.where((n) => n != '快走' && n != '慢跑').length,
                      reason: '同一天重複：$names');
                  for (final e in day.items) {
                    final def = findExercise(e.name);
                    expect(def, isNotNull, reason: '${e.name} 不在動作庫');
                    expect(hasEquipmentFor(def!, eq), isTrue, reason: '${e.name} 需要 ${def.equipment}');
                    expect(def.isValidAmount(e.amount), isTrue,
                        reason: '${e.name} ${e.amount}${def.unit} 超出 ${def.minAmount}–${def.maxAmount}');
                  }
                }
              }
            }
          }
        }
      }
    });

    test('50 歲以上：增肌組數 4→3', () {
      expect(plan(goal: Goal.bulk, days: 5, age: 55).days[0].items.first.sets, 3);
    });

    test('50 歲以上：有氧改快走並少 10 分鐘、不排高衝擊動作', () {
      final p = plan(goal: Goal.maintain, days: 5, age: 55);
      final cardioDay = p.days.firstWhere((d) => d.type == DayType.cardio);
      expect(cardioDay.items.single.name, '快走');
      expect(cardioDay.items.single.minutes, 20); // 維持 30 − 10
      expect(allItems(p).any((e) => e.exercise.highImpact), isFalse);
      expect(p.notes.any((n) => n.contains('50 歲以上')), isTrue);
    });

    test('BMI ≥ 27：伏地挺身改跪姿、不跑不跳，並說明原因', () {
      final p = plan(goal: Goal.cut, days: 4, weight: 95, height: 175); // BMI 31
      final names = allItems(p).map((e) => e.name).toSet();
      expect(names, contains('跪姿伏地挺身'));
      expect(names, isNot(contains('伏地挺身')));
      expect(names, isNot(contains('慢跑')));
      expect(allItems(p).any((e) => e.exercise.highImpact), isFalse);
      expect(p.notes.any((n) => n.contains('偏高')), isTrue);
    });

    test('BMI 標準的年輕人：一般強度（慢跑、高腳杯深蹲）', () {
      final p = plan(goal: Goal.cut, days: 3);
      final names = allItems(p).map((e) => e.name).toSet();
      expect(names, containsAll(['慢跑', '高腳杯深蹲', '伏地挺身']));
      expect(p.notes.any((n) => n.contains('標準')), isTrue);
    });

    test('BMI 過輕：有氧最多 20 分鐘，減脂也不在重訓後補有氧', () {
      final p = plan(goal: Goal.cut, days: 5, weight: 48, height: 175); // BMI 15.7
      final cardio = allItems(p).where((e) => e.category == ExerciseTaskCategory.cardio);
      expect(cardio, isNotEmpty);
      expect(cardio.every((e) => e.minutes! <= 20), isTrue);
      final strengthDay = p.days.firstWhere((d) => d.type.isStrength);
      expect(strengthDay.items.every((e) => e.category == ExerciseTaskCategory.strength),
          isTrue);
      expect(p.notes.any((n) => n.contains('偏低')), isTrue);
    });

    test('減脂：重訓日最後補 15 分鐘有氧', () {
      final p = plan(goal: Goal.cut, days: 3);
      final fullBody = p.days.firstWhere((d) => d.type == DayType.fullBody);
      expect(fullBody.items.last.category, ExerciseTaskCategory.cardio);
      expect(fullBody.items.last.minutes, 15);
    });

    test('休息日排伸展（分類是伸展，不是有氧）', () {
      final rest = plan().days.firstWhere((d) => d.type == DayType.rest);
      expect(rest.items.single.category, ExerciseTaskCategory.flexibility);
    });

    test('每組次數依目標：增肌 8–12、減脂 12–15；棒式以秒計', () {
      final bulk = plan(goal: Goal.bulk);
      final squat = bulk.days[0].items.first;
      expect(bulk.doseOf(squat), '4 組 × 8–12 下');
      final plank = allItems(bulk).firstWhere((e) => e.name == '棒式');
      expect(bulk.doseOf(plank), '4 組 × 30–45 秒');
      expect(plan(goal: Goal.cut).repRange, '12–15 下');
    });

    test('預估時間：暖身 5 + 每組 2 分鐘，四捨五入到 5', () {
      // 增肌全身日：4 個動作 × 4 組 = 16 組 → 5 + 32 = 37 → 35
      expect(plan(goal: Goal.bulk).days[0].estimatedMinutes, 35);
    });
  });

  group('依器材挑動作', () {
    Set<String> strengthNames(WeeklyPlan p) => allItems(p)
        .where((e) => e.category == ExerciseTaskCategory.strength)
        .map((e) => e.name)
        .toSet();

    test('只有徒手：全部是徒手動作（背用超人式、肩用派克伏地挺身）', () {
      final p = plan(goal: Goal.bulk, days: 5, equipment: _bodyweightOnly);
      for (final e in allItems(p).where((e) => e.category == ExerciseTaskCategory.strength)) {
        expect(e.exercise.equipment, Equipment.bodyweight, reason: e.name);
      }
      expect(strengthNames(p), containsAll(['徒手深蹲', '伏地挺身', '超人式', '派克伏地挺身']));
      expect(p.notes.first, '器材：徒手，動作都用這些器材安排');
    });

    test('居家啞鈴：高腳杯深蹲、啞鈴划船、啞鈴肩推；沒有臥推椅所以胸還是伏地挺身', () {
      final p = plan(goal: Goal.bulk, days: 5);
      expect(strengthNames(p), containsAll(['高腳杯深蹲', '啞鈴划船', '啞鈴肩推', '伏地挺身']));
      expect(strengthNames(p), isNot(contains('槓鈴深蹲')));
    });

    test('健身房：槓鈴深蹲、槓鈴臥推、滑輪下拉、槓鈴臀推', () {
      final p = plan(goal: Goal.bulk, days: 5, equipment: _gym);
      expect(strengthNames(p), containsAll(['槓鈴深蹲', '槓鈴臥推', '滑輪下拉', '槓鈴臀推']));
      expect(p.notes.first, contains('槓鈴'));
    });

    test('健身房 + 50 歲以上：下肢用腿推（坐著做），不排槓鈴深蹲', () {
      final p = plan(goal: Goal.bulk, days: 5, age: 60, equipment: _gym);
      expect(strengthNames(p), contains('腿推'));
      expect(strengthNames(p), isNot(contains('槓鈴深蹲')));
    });
  });

  group('planToTasks', () {
    test('只排今天到週日', () {
      final p = plan(goal: Goal.maintain, days: 3);
      // 2026-10-1 是週四
      final tasks = planToTasks(p, DateTime(2026, 10, 1));
      expect(tasks.keys, ['2026-10-1', '2026-10-2', '2026-10-3', '2026-10-4']);
    });

    test('週日只排當天；跨月的週也算對日期', () {
      final p = plan();
      expect(planToTasks(p, DateTime(2026, 10, 4)).keys, ['2026-10-4']);
      // 2026-9-28 是週一：一路排到 10/4
      expect(planToTasks(p, DateTime(2026, 9, 28)).keys.last, '2026-10-4');
    });

    test('轉成 ExerciseTask：重訓帶組數、有氧 / 伸展帶分鐘數', () {
      final p = plan(goal: Goal.cut, days: 3);
      final monday = planToTasks(p, DateTime(2026, 9, 28))['2026-9-28']!;
      for (final t in monday) {
        expect(t.date, '2026-9-28');
        expect(t.done, isFalse);
        if (t.category.usesSets) {
          expect(t.sets, isNotNull);
          expect(t.minutes, isNull);
        } else {
          expect(t.minutes, isNotNull);
          expect(t.sets, isNull);
        }
      }
    });
  });
}
