import '../utils/exercise_catalog.dart';
import '../utils/nutrition_math.dart';
import '../utils/workout_planner.dart';

/// 使用者個人資料（DB 只存一列，id 固定為 1）。
/// Onboarding 時建立，之後可在設定頁修改。
class UserProfile {
  UserProfile({
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.sex,
    required this.activity,
    required this.goal,
    this.workoutWeekdays = const {1, 3, 5},
    Set<Equipment> equipment = const {Equipment.dumbbell},
  }) : equipment = {Equipment.bodyweight, ...equipment};

  final double heightCm;
  final double weightKg; // 最近一次體重（也會寫進 weight_log）
  final int age;
  final Sex sex;
  final ActivityLevel activity;
  final Goal goal;
  final Set<int> workoutWeekdays; // 每週哪幾天運動（1 = 週一 … 7 = 週日），最多 6 天

  int get workoutDays => workoutWeekdays.length;

  /// 有哪些器材可以用（一定包含徒手），排計畫和挑動作都只用這些器材
  final Set<Equipment> equipment;

  /// 依目前資料算出的每日熱量與三大營養素目標
  NutritionTargets get targets => computeTargets(
        sex: sex,
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        activity: activity,
        goal: goal,
      );

  UserProfile copyWith({
    double? heightCm,
    double? weightKg,
    int? age,
    Sex? sex,
    ActivityLevel? activity,
    Goal? goal,
    Set<int>? workoutWeekdays,
    Set<Equipment>? equipment,
  }) {
    return UserProfile(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      activity: activity ?? this.activity,
      goal: goal ?? this.goal,
      workoutWeekdays: workoutWeekdays ?? this.workoutWeekdays,
      equipment: equipment ?? this.equipment,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': 1,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'age': age,
        'sex': sex.name,
        'activity_level': activity.name,
        'goal': goal.name,
        'workout_days': workoutDays,
        'workout_weekdays': (workoutWeekdays.toList()..sort()).join(','),
        // 依 enum 順序存成逗號分隔，例如 "bodyweight,dumbbell"
        'equipment': [
          for (final e in Equipment.values)
            if (equipment.contains(e)) e.name
        ].join(','),
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      heightCm: (map['height_cm'] as num).toDouble(),
      weightKg: (map['weight_kg'] as num).toDouble(),
      age: (map['age'] as num).toInt(),
      sex: Sex.values.byName(map['sex'] as String),
      activity: ActivityLevel.values.byName(map['activity_level'] as String),
      goal: Goal.values.byName(map['goal'] as String),
      // 版本 14 以前只存天數：用預設的運動日分配
      workoutWeekdays: map['workout_weekdays'] == null
          ? defaultWorkoutWeekdays((map['workout_days'] as num?)?.toInt() ?? 3)
          : {
              for (final d in (map['workout_weekdays'] as String).split(','))
                if (d.isNotEmpty) int.parse(d)
            },
      equipment: map['equipment'] == null
          ? const {Equipment.dumbbell}
          : {
              for (final name in (map['equipment'] as String).split(','))
                if (name.isNotEmpty) Equipment.values.byName(name)
            },
    );
  }
}

/// 一筆體重紀錄
class WeightEntry {
  WeightEntry({required this.date, required this.weightKg});

  final String date; // yyyy-M-d
  final double weightKg;

  factory WeightEntry.fromMap(Map<String, dynamic> map) => WeightEntry(
        date: map['date'] as String,
        weightKg: (map['weight_kg'] as num).toDouble(),
      );
}
