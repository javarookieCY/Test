import '../utils/exercise_catalog.dart';
import '../utils/nutrition_math.dart';
import '../utils/workout_planner.dart';

/// 使用者個人資料（DB 只存一列，id 固定為 1）。
/// Onboarding 時建立，之後可在設定頁修改。
class UserProfile {
  // 冒號後面是「初始化列表」：在建構子內容執行之前先設定 final 欄位
  // 這裡把傳進來的器材再加上「徒手」，所以 equipment 一定包含徒手
  UserProfile({
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.sex,
    required this.activity,
    required this.goal,
    this.workoutWeekdays = const <int>{1, 3, 5}, // 不填就是週一、三、五
    Set<Equipment> equipment = const <Equipment>{Equipment.dumbbell}, // 不填就是啞鈴
  }) : equipment = _withBodyweight(equipment);

  final double heightCm;
  final double weightKg; // 最近一次體重（也會寫進 weight_log）
  final int age;
  final Sex sex;
  final ActivityLevel activity;
  final Goal goal;
  final Set<int> workoutWeekdays; // 每週哪幾天運動（1 = 週一 … 7 = 週日），最多 6 天

  /// 有哪些器材可以用（一定包含徒手），排計畫和挑動作都只用這些器材
  final Set<Equipment> equipment;

  /// 回傳一個新的 Set：徒手 + 傳進來的所有器材
  static Set<Equipment> _withBodyweight(Set<Equipment> equipment) {
    final Set<Equipment> result = <Equipment>{};
    result.add(Equipment.bodyweight);
    for (final Equipment item in equipment) {
      result.add(item);
    }
    return result;
  }

  /// 每週運動幾天
  int get workoutDays {
    return workoutWeekdays.length;
  }

  /// 依目前資料算出的每日熱量與三大營養素目標(每次讀取都重新計算，不存資料庫)
  NutritionTargets get targets {
    final NutritionTargets result = computeTargets(
      sex: sex,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      activity: activity,
      goal: goal,
    );
    return result;
  }

  /// 複製一份，只改有傳進來的欄位；沒傳的(null)沿用目前的值
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
    // 參數和欄位同名時，this.xxx 指的是欄位，沒有 this 的是參數
    double newHeightCm = this.heightCm;
    if (heightCm != null) {
      newHeightCm = heightCm;
    }

    double newWeightKg = this.weightKg;
    if (weightKg != null) {
      newWeightKg = weightKg;
    }

    int newAge = this.age;
    if (age != null) {
      newAge = age;
    }

    Sex newSex = this.sex;
    if (sex != null) {
      newSex = sex;
    }

    ActivityLevel newActivity = this.activity;
    if (activity != null) {
      newActivity = activity;
    }

    Goal newGoal = this.goal;
    if (goal != null) {
      newGoal = goal;
    }

    Set<int> newWorkoutWeekdays = this.workoutWeekdays;
    if (workoutWeekdays != null) {
      newWorkoutWeekdays = workoutWeekdays;
    }

    Set<Equipment> newEquipment = this.equipment;
    if (equipment != null) {
      newEquipment = equipment;
    }

    return UserProfile(
      heightCm: newHeightCm,
      weightKg: newWeightKg,
      age: newAge,
      sex: newSex,
      activity: newActivity,
      goal: newGoal,
      workoutWeekdays: newWorkoutWeekdays,
      equipment: newEquipment,
    );
  }

  /// 物件 → Map(存進資料庫用)
  Map<String, dynamic> toMap() {
    // 運動日：{5, 1, 3} → 排序成 [1, 3, 5] → 存成 "1,3,5"
    final List<int> sortedWeekdays = workoutWeekdays.toList();
    sortedWeekdays.sort();
    final String weekdaysText = sortedWeekdays.join(',');

    // 器材：依 enum 的順序存成逗號分隔，例如 "bodyweight,dumbbell"
    final List<String> equipmentNames = <String>[];
    for (final Equipment item in Equipment.values) {
      if (equipment.contains(item)) {
        equipmentNames.add(item.name);
      }
    }
    final String equipmentText = equipmentNames.join(',');

    final Map<String, dynamic> map = <String, dynamic>{
      'id': 1,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'age': age,
      'sex': sex.name, // enum 的名字，例如 Sex.male → "male"
      'activity_level': activity.name,
      'goal': goal.name,
      'workout_days': workoutDays,
      'workout_weekdays': weekdaysText,
      'equipment': equipmentText,
    };
    return map;
  }

  /// Map → 物件(從資料庫讀出來用)
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final num heightNumber = map['height_cm'] as num;
    final num weightNumber = map['weight_kg'] as num;
    final num ageNumber = map['age'] as num;

    // 字串 → enum，例如 "male" → Sex.male
    final Sex sex = Sex.values.byName(map['sex'] as String);
    final ActivityLevel activity = ActivityLevel.values.byName(map['activity_level'] as String);
    final Goal goal = Goal.values.byName(map['goal'] as String);

    // 運動日
    Set<int> workoutWeekdays;
    final Object? weekdaysValue = map['workout_weekdays'];
    if (weekdaysValue == null) {
      // 版本 14 以前只存「每週幾天」：用預設的運動日分配
      int days = 3;
      final Object? daysValue = map['workout_days'];
      if (daysValue != null) {
        final num daysNumber = daysValue as num;
        days = daysNumber.toInt();
      }
      workoutWeekdays = defaultWorkoutWeekdays(days);
    } else {
      // "1,3,5" → {1, 3, 5}
      workoutWeekdays = <int>{};
      final List<String> parts = (weekdaysValue as String).split(',');
      for (final String part in parts) {
        if (part.isNotEmpty) {
          workoutWeekdays.add(int.parse(part));
        }
      }
    }

    // 器材
    Set<Equipment> equipment;
    final Object? equipmentValue = map['equipment'];
    if (equipmentValue == null) {
      equipment = <Equipment>{Equipment.dumbbell};
    } else {
      // "bodyweight,dumbbell" → {Equipment.bodyweight, Equipment.dumbbell}
      equipment = <Equipment>{};
      final List<String> names = (equipmentValue as String).split(',');
      for (final String name in names) {
        if (name.isNotEmpty) {
          equipment.add(Equipment.values.byName(name));
        }
      }
    }

    return UserProfile(
      heightCm: heightNumber.toDouble(),
      weightKg: weightNumber.toDouble(),
      age: ageNumber.toInt(),
      sex: sex,
      activity: activity,
      goal: goal,
      workoutWeekdays: workoutWeekdays,
      equipment: equipment,
    );
  }
}

/// 一筆體重紀錄
class WeightEntry {
  WeightEntry({required this.date, required this.weightKg});

  final String date; // yyyy-M-d
  final double weightKg;

  /// Map → 物件(從資料庫讀出來用)
  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    final String date = map['date'] as String;
    final num weightNumber = map['weight_kg'] as num;
    return WeightEntry(
      date: date,
      weightKg: weightNumber.toDouble(),
    );
  }
}
